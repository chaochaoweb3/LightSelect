/**
 * Adapted from selection-hook 2.0.3 src/mac/selection_hook.mm.
 * Copyright (c) 2025 0xfullex. Licensed under the MIT License.
 *
 * LightSelect replaces the upstream N-API object and thread-safe JavaScript
 * callbacks with a small C ABI. Gesture, AX, position, fullscreen, filtering,
 * and clipboard fallback behavior remains native macOS code.
 */

#import "SelectionHookNative.h"

#import <algorithm>
#import <atomic>
#import <chrono>
#import <cmath>
#import <future>
#import <mutex>
#import <string>
#import <thread>
#import <vector>

#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

#import "clipboard.h"
#import "utils.h"

namespace {

constexpr int MIN_DRAG_DISTANCE = 8;
constexpr uint64_t MAX_DRAG_TIME_MS = 15000;
constexpr int DOUBLE_CLICK_MAX_DISTANCE = 3;
constexpr uint64_t DOUBLE_CLICK_TIME_MS = 500;

enum class SelectionDetectType { None = 0, Drag = 1, DoubleClick = 2, ShiftClick = 3 };
enum class SelectionMethod { None = 0, AXAPI = 11, Clipboard = 99 };
enum class SelectionPositionLevel { None = 0, MouseSingle = 1, MouseDual = 2, Full = 3, Detailed = 4 };
enum class FilterMode { Default = 0, IncludeList = 1, ExcludeList = 2 };

struct TextSelectionInfo {
    std::string text;
    std::string programName;
    CGPoint startTop = CGPointZero;
    CGPoint startBottom = CGPointZero;
    CGPoint endTop = CGPointZero;
    CGPoint endBottom = CGPointZero;
    CGPoint mousePosStart = CGPointZero;
    CGPoint mousePosEnd = CGPointZero;
    SelectionMethod method = SelectionMethod::None;
    SelectionPositionLevel posLevel = SelectionPositionLevel::None;
    bool isFullscreen = false;
};

struct MouseEventContext {
    CGEventType type;
    CGPoint position;
    CGEventFlags flags;
    uint64_t timestampMs;
    bool cursorIBeam;
    int64_t clipboardSequence;
};

class NativeSelectionHook {
  public:
    NativeSelectionHook(LSSelectionCallback callback, void *context)
        : callback_(callback), callback_context_(context), processing_queue_(dispatch_queue_create(
              "local.ccw3.LightSelect.selection-hook", DISPATCH_QUEUE_SERIAL)) {}

    ~NativeSelectionHook() { Stop(); }

    bool Start() {
        if (running_.exchange(true) || event_thread_.joinable()) {
            return false;
        }

        ResetGestureState();
        event_run_loop_promise_ = std::promise<CFRunLoopRef>();
        event_run_loop_future_ = event_run_loop_promise_.get_future();
        event_thread_ = std::thread(&NativeSelectionHook::EventThreadProc, this);
        CFRunLoopRef runLoop = event_run_loop_future_.get();
        if (!runLoop) {
            running_ = false;
            if (event_thread_.joinable()) event_thread_.join();
            return false;
        }
        return true;
    }

    void Stop() {
        running_ = false;
        if (event_thread_.joinable()) {
            if (event_run_loop_) CFRunLoopStop(event_run_loop_);
            event_thread_.join();
        }
        dispatch_sync(processing_queue_, ^{});
        event_run_loop_ = nullptr;
    }

    void SetPassive(bool passive) { passive_ = passive; }

    void SetFilter(FilterMode mode, const char *const *identifiers, size_t count) {
        std::lock_guard<std::mutex> lock(filter_mutex_);
        filter_mode_ = mode;
        filter_list_.clear();
        for (size_t index = 0; index < count; ++index) {
            if (!identifiers || !identifiers[index]) continue;
            std::string value(identifiers[index]);
            std::transform(value.begin(), value.end(), value.begin(), [](unsigned char character) {
                return static_cast<char>(std::tolower(character));
            });
            filter_list_.push_back(std::move(value));
        }
    }

    bool Current(LSSelectionCallback callback, void *context) {
        @autoreleasepool {
            NSRunningApplication *frontApp = GetFrontApp();
            TextSelectionInfo selection;
            if (!GetSelectedText(frontApp, selection) || IsTrimmedEmpty(selection.text)) return false;
            Emit(selection, callback, context);
            return true;
        }
    }

  private:
    static CGEventRef MouseEventCallback(CGEventTapProxy, CGEventType type, CGEventRef event, void *context) {
        auto *hook = static_cast<NativeSelectionHook *>(context);
        if (!hook || !hook->running_) return event;
        if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
            if (hook->mouse_event_tap_) CGEventTapEnable(hook->mouse_event_tap_, true);
            return event;
        }
        if (type != kCGEventLeftMouseDown && type != kCGEventLeftMouseUp) return event;

        bool cursorIBeam = false;
        int64_t clipboardSequence = -1;
        @autoreleasepool {
            cursorIBeam = IsIBeamCursor([NSCursor currentSystemCursor]);
            if (type == kCGEventLeftMouseDown) clipboardSequence = GetClipboardSequence();
        }

        MouseEventContext snapshot{
            .type = type,
            .position = CGEventGetLocation(event),
            .flags = CGEventGetFlags(event),
            .timestampMs = CGEventGetTimestamp(event) / 1000000ULL,
            .cursorIBeam = cursorIBeam,
            .clipboardSequence = clipboardSequence,
        };
        dispatch_async(hook->processing_queue_, ^{
            if (hook->running_) hook->ProcessMouseEvent(snapshot);
        });
        return event;
    }

    static CGEventRef KeyboardEventCallback(CGEventTapProxy, CGEventType type, CGEventRef event, void *context) {
        auto *hook = static_cast<NativeSelectionHook *>(context);
        if (hook && (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) &&
            hook->keyboard_event_tap_) {
            CGEventTapEnable(hook->keyboard_event_tap_, true);
        }
        return event;
    }

    void EventThreadProc() {
        @autoreleasepool {
            CGEventMask mouseMask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp);
            mouse_event_tap_ = CGEventTapCreate(
                kCGSessionEventTap,
                kCGTailAppendEventTap,
                kCGEventTapOptionListenOnly,
                mouseMask,
                MouseEventCallback,
                this
            );
            if (!mouse_event_tap_) {
                event_run_loop_promise_.set_value(nullptr);
                return;
            }

            CGEventMask keyboardMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) |
                                       CGEventMaskBit(kCGEventFlagsChanged);
            keyboard_event_tap_ = CGEventTapCreate(
                kCGSessionEventTap,
                kCGTailAppendEventTap,
                kCGEventTapOptionListenOnly,
                keyboardMask,
                KeyboardEventCallback,
                this
            );
            event_run_loop_ = CFRunLoopGetCurrent();
            mouse_source_ = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouse_event_tap_, 0);
            CFRunLoopAddSource(event_run_loop_, mouse_source_, kCFRunLoopDefaultMode);
            CGEventTapEnable(mouse_event_tap_, true);

            if (keyboard_event_tap_) {
                keyboard_source_ = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyboard_event_tap_, 0);
                CFRunLoopAddSource(event_run_loop_, keyboard_source_, kCFRunLoopDefaultMode);
                CGEventTapEnable(keyboard_event_tap_, true);
            }
            running_pid_ = getpid();
            event_run_loop_promise_.set_value(event_run_loop_);
            CFRunLoopRun();

            if (mouse_event_tap_) {
                CGEventTapEnable(mouse_event_tap_, false);
                CFRunLoopRemoveSource(event_run_loop_, mouse_source_, kCFRunLoopDefaultMode);
                CFRelease(mouse_source_);
                CFRelease(mouse_event_tap_);
                mouse_source_ = nullptr;
                mouse_event_tap_ = nullptr;
            }
            if (keyboard_event_tap_) {
                CGEventTapEnable(keyboard_event_tap_, false);
                CFRunLoopRemoveSource(event_run_loop_, keyboard_source_, kCFRunLoopDefaultMode);
                CFRelease(keyboard_source_);
                CFRelease(keyboard_event_tap_);
                keyboard_source_ = nullptr;
                keyboard_event_tap_ = nullptr;
            }
            event_run_loop_ = nullptr;
        }
    }

    void ProcessMouseEvent(const MouseEventContext &event) {
        if (event.type == kCGEventLeftMouseDown) {
            last_mouse_down_time_ = event.timestampMs;
            last_mouse_down_pos_ = event.position;
            last_mouse_down_valid_cursor_ = event.cursorIBeam;
            clipboard_sequence_ = event.clipboardSequence;
            return;
        }
        if (event.type != kCGEventLeftMouseUp) return;

        SelectionDetectType detection = SelectionDetectType::None;
        bool shouldDetect = false;
        const uint64_t elapsed = event.timestampMs - last_mouse_down_time_;
        const double dx = event.position.x - last_mouse_down_pos_.x;
        const double dy = event.position.y - last_mouse_down_pos_.y;
        const double distance = std::sqrt(dx * dx + dy * dy);
        const bool currentValidClick = elapsed <= DOUBLE_CLICK_TIME_MS;
        const bool validCursor = last_mouse_down_valid_cursor_ || event.cursorIBeam;

        if (!passive_ && elapsed <= MAX_DRAG_TIME_MS) {
            if (distance >= MIN_DRAG_DISTANCE && validCursor) {
                shouldDetect = true;
                detection = SelectionDetectType::Drag;
            } else if (last_valid_click_ && currentValidClick && distance <= DOUBLE_CLICK_MAX_DISTANCE) {
                const double upDX = event.position.x - last_mouse_up_pos_.x;
                const double upDY = event.position.y - last_mouse_up_pos_.y;
                if (std::sqrt(upDX * upDX + upDY * upDY) <= DOUBLE_CLICK_MAX_DISTANCE &&
                    last_mouse_down_time_ - last_mouse_up_time_ <= DOUBLE_CLICK_TIME_MS && validCursor) {
                    shouldDetect = true;
                    detection = SelectionDetectType::DoubleClick;
                }
            }

            if (!shouldDetect) {
                const bool shift = (event.flags & kCGEventFlagMaskShift) != 0;
                const bool otherModifier = (event.flags & (kCGEventFlagMaskControl | kCGEventFlagMaskCommand |
                                                            kCGEventFlagMaskAlternate)) != 0;
                if (shift && !otherModifier && validCursor) {
                    shouldDetect = true;
                    detection = SelectionDetectType::ShiftClick;
                }
            }
            last_valid_click_ = currentValidClick;
        }

        last_last_mouse_up_pos_ = last_mouse_up_pos_;
        last_mouse_up_time_ = event.timestampMs;
        last_mouse_up_pos_ = event.position;
        if (!shouldDetect) return;

        @autoreleasepool {
            TextSelectionInfo selection;
            if (!GetSelectedText(GetFrontApp(), selection) || IsTrimmedEmpty(selection.text)) return;
            switch (detection) {
            case SelectionDetectType::Drag:
                selection.mousePosStart = last_mouse_down_pos_;
                selection.mousePosEnd = last_mouse_up_pos_;
                if (selection.posLevel == SelectionPositionLevel::None) selection.posLevel = SelectionPositionLevel::MouseDual;
                break;
            case SelectionDetectType::DoubleClick:
                selection.mousePosStart = last_mouse_up_pos_;
                selection.mousePosEnd = last_mouse_up_pos_;
                if (selection.posLevel == SelectionPositionLevel::None) selection.posLevel = SelectionPositionLevel::MouseSingle;
                break;
            case SelectionDetectType::ShiftClick:
                selection.mousePosStart = last_last_mouse_up_pos_;
                selection.mousePosEnd = last_mouse_up_pos_;
                if (selection.posLevel == SelectionPositionLevel::None) selection.posLevel = SelectionPositionLevel::MouseDual;
                break;
            case SelectionDetectType::None:
                break;
            }
            Emit(selection, callback_, callback_context_);
        }
    }

    bool GetSelectedText(NSRunningApplication *frontApp, TextSelectionInfo &selection) {
        if (!frontApp) return false;
        bool expected = false;
        if (!processing_.compare_exchange_strong(expected, true)) return false;
        struct ProcessingReset {
            std::atomic<bool> &value;
            ~ProcessingReset() { value = false; }
        } reset{processing_};

        if (!GetProgramNameFromFrontApp(frontApp, selection.programName) || !AllowsProgram(selection.programName)) {
            return false;
        }

        bool result = false;
        if (GetTextViaAXAPI(frontApp, selection)) {
            selection.method = SelectionMethod::AXAPI;
            result = true;
        } else if (GetTextViaClipboard(frontApp, selection)) {
            selection.method = SelectionMethod::Clipboard;
            result = true;
        }
        if (result) selection.isFullscreen = IsWindowFullscreen(frontApp);
        return result;
    }

    bool AllowsProgram(const std::string &programName) {
        std::lock_guard<std::mutex> lock(filter_mutex_);
        if (filter_mode_ == FilterMode::Default) return true;
        std::string normalized = programName;
        std::transform(normalized.begin(), normalized.end(), normalized.begin(), [](unsigned char character) {
            return static_cast<char>(std::tolower(character));
        });
        bool contains = false;
        for (const auto &item : filter_list_) {
            if (normalized.find(item) != std::string::npos) {
                contains = true;
                break;
            }
        }
        return filter_mode_ == FilterMode::IncludeList ? contains : !contains;
    }

    bool GetTextViaAXAPI(NSRunningApplication *frontApp, TextSelectionInfo &selection) {
        AXUIElementRef appElement = GetAppElementFromFrontApp(frontApp);
        if (!appElement) return false;
        AXUIElementRef focusedElement = GetFocusedElementFromAppElement(appElement);
        if (!focusedElement) focusedElement = GetFrontWindowElementFromAppElement(appElement);
        if (!focusedElement) {
            CFRelease(appElement);
            return false;
        }

        bool result = TryElement(focusedElement, selection);
        if (!result) {
            CFArrayRef children = nullptr;
            if (AXUIElementCopyAttributeValue(focusedElement, kAXChildrenAttribute, (CFTypeRef *)&children) ==
                    kAXErrorSuccess && children) {
                for (CFIndex index = 0; index < CFArrayGetCount(children) && !result; ++index) {
                    auto child = (AXUIElementRef)CFArrayGetValueAtIndex(children, index);
                    if (child) result = TryElement(child, selection);
                }
                CFRelease(children);
            }
        }

        if (!result) {
            AXUIElementRef current = focusedElement;
            CFRetain(current);
            for (int level = 0; level < 10 && !result; ++level) {
                AXUIElementRef parent = nullptr;
                AXError error = AXUIElementCopyAttributeValue(current, kAXParentAttribute, (CFTypeRef *)&parent);
                CFRelease(current);
                current = nullptr;
                if (error != kAXErrorSuccess || !parent) break;
                current = parent;
                result = TryElement(current, selection);
            }
            if (current) CFRelease(current);
        }

        if (!result) {
            AXUIElementSetAttributeValue(appElement, CFSTR("AXEnhancedUserInterface"), kCFBooleanTrue);
            AXUIElementSetAttributeValue(appElement, CFSTR("AXManualAccessibility"), kCFBooleanTrue);
        }
        CFRelease(focusedElement);
        CFRelease(appElement);
        return result;
    }

    bool TryElement(AXUIElementRef element, TextSelectionInfo &selection) {
        std::string text;
        if (!GetSelectedTextFromElement(element, text) || text.empty() || IsTrimmedEmpty(text)) return false;
        selection.text = text;
        if (!SetTextRangeCoordinates(element, selection)) selection.posLevel = SelectionPositionLevel::None;
        return true;
    }

    bool GetSelectedTextFromElement(AXUIElementRef element, std::string &text) {
        if (!element) return false;
        CFTypeRef selectedTextRef = nullptr;
        AXError error = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute, &selectedTextRef);
        if (error == kAXErrorSuccess && selectedTextRef) {
            if (CFGetTypeID(selectedTextRef) == CFStringGetTypeID()) {
                CFStringRef selectedText = (CFStringRef)selectedTextRef;
                CFIndex length = CFStringGetLength(selectedText);
                if (length > 0) {
                    CFIndex maximum = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
                    std::vector<char> buffer(static_cast<size_t>(maximum));
                    if (CFStringGetCString(selectedText, buffer.data(), maximum, kCFStringEncodingUTF8)) {
                        text.assign(buffer.data());
                    }
                }
            } else if (CFGetTypeID(selectedTextRef) == CFNumberGetTypeID()) {
                CFNumberRef number = (CFNumberRef)selectedTextRef;
                if (CFNumberIsFloatType(number)) {
                    double value = 0;
                    if (CFNumberGetValue(number, kCFNumberDoubleType, &value)) text = std::to_string(value);
                } else {
                    long value = 0;
                    if (CFNumberGetValue(number, kCFNumberLongType, &value)) text = std::to_string(value);
                }
            }
            CFRelease(selectedTextRef);
            if (!text.empty()) return true;
        }

        CFTypeRef valueRef = nullptr;
        error = AXUIElementCopyAttributeValue(element, kAXValueAttribute, &valueRef);
        if (error != kAXErrorSuccess || !valueRef) return false;
        if (CFGetTypeID(valueRef) != CFStringGetTypeID()) {
            CFRelease(valueRef);
            return false;
        }

        AXValueRef rangeValue = nullptr;
        error = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute, (CFTypeRef *)&rangeValue);
        if (error != kAXErrorSuccess || !rangeValue) {
            CFRelease(valueRef);
            return false;
        }
        CFRange range = {0, 0};
        bool result = false;
        if (AXValueGetValue(rangeValue, kAXValueTypeCFRange, &range)) {
            CFIndex valueLength = CFStringGetLength((CFStringRef)valueRef);
            if (valueLength > 0 && range.length > 0) {
                range.location = std::max<CFIndex>(0, std::min<CFIndex>(range.location, valueLength - 1));
                range.length = std::min<CFIndex>(range.length, valueLength - range.location);
                if (range.length > 0) {
                    CFStringRef substring = CFStringCreateWithSubstring(kCFAllocatorDefault, (CFStringRef)valueRef, range);
                    if (substring) {
                        CFIndex maximum = CFStringGetMaximumSizeForEncoding(CFStringGetLength(substring),
                                                                            kCFStringEncodingUTF8) + 1;
                        std::vector<char> buffer(static_cast<size_t>(maximum));
                        if (CFStringGetCString(substring, buffer.data(), maximum, kCFStringEncodingUTF8)) {
                            text.assign(buffer.data());
                            result = !text.empty();
                        }
                        CFRelease(substring);
                    }
                }
            }
        }
        CFRelease(rangeValue);
        CFRelease(valueRef);
        return result;
    }

    bool SetTextRangeCoordinates(AXUIElementRef element, TextSelectionInfo &selection) {
        AXValueRef selectedRangeValue = nullptr;
        AXError error = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute,
                                                       (CFTypeRef *)&selectedRangeValue);
        if (error == kAXErrorSuccess && selectedRangeValue) {
            CFRange selectedRange = {0, 0};
            if (AXValueGetValue(selectedRangeValue, kAXValueTypeCFRange, &selectedRange) && selectedRange.length > 0) {
                CFRange firstRange = {selectedRange.location, 1};
                CFRange lastRange = {selectedRange.location + selectedRange.length - 1, 1};
                AXValueRef firstRangeValue = AXValueCreate(kAXValueTypeCFRange, &firstRange);
                AXValueRef lastRangeValue = AXValueCreate(kAXValueTypeCFRange, &lastRange);
                AXValueRef firstBounds = nullptr;
                AXValueRef lastBounds = nullptr;
                if (firstRangeValue && lastRangeValue &&
                    AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute,
                                                               firstRangeValue, (CFTypeRef *)&firstBounds) == kAXErrorSuccess &&
                    AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute,
                                                               lastRangeValue, (CFTypeRef *)&lastBounds) == kAXErrorSuccess &&
                    firstBounds && lastBounds) {
                    CGRect firstRect = CGRectZero;
                    CGRect lastRect = CGRectZero;
                    if (AXValueGetValue(firstBounds, kAXValueTypeCGRect, &firstRect) &&
                        AXValueGetValue(lastBounds, kAXValueTypeCGRect, &lastRect) &&
                        ValidCharacterRect(firstRect) && ValidCharacterRect(lastRect)) {
                        SetCoordinates(firstRect, lastRect, selection);
                        CFRelease(firstBounds);
                        CFRelease(lastBounds);
                        CFRelease(firstRangeValue);
                        CFRelease(lastRangeValue);
                        CFRelease(selectedRangeValue);
                        return true;
                    }
                }
                if (firstBounds) CFRelease(firstBounds);
                if (lastBounds) CFRelease(lastBounds);
                if (firstRangeValue) CFRelease(firstRangeValue);
                if (lastRangeValue) CFRelease(lastRangeValue);
            }
            CFRelease(selectedRangeValue);
        }

        selectedRangeValue = nullptr;
        error = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute,
                                               (CFTypeRef *)&selectedRangeValue);
        if (error == kAXErrorSuccess && selectedRangeValue) {
            CFRange selectedRange = {0, 0};
            AXValueRef bounds = nullptr;
            if (AXValueGetValue(selectedRangeValue, kAXValueTypeCFRange, &selectedRange) && selectedRange.length > 0 &&
                AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute,
                                                           selectedRangeValue, (CFTypeRef *)&bounds) == kAXErrorSuccess && bounds) {
                CGRect rect = CGRectZero;
                if (AXValueGetValue(bounds, kAXValueTypeCGRect, &rect) && ValidRangeRect(rect)) {
                    SetCoordinates(rect, rect, selection);
                    CFRelease(bounds);
                    CFRelease(selectedRangeValue);
                    return true;
                }
            }
            if (bounds) CFRelease(bounds);
            CFRelease(selectedRangeValue);
        }
        return false;
    }

    static bool ValidCharacterRect(CGRect rect) {
        return rect.size.width > 1 && rect.size.height > 0 && rect.size.height < 100 && rect.origin.x >= 0 &&
               rect.origin.y >= 0 && rect.origin.x < 10000 && rect.origin.y < 10000;
    }

    static bool ValidRangeRect(CGRect rect) {
        return rect.size.width > 0 && rect.size.height > 0 && rect.origin.x >= 0 && rect.origin.y >= 0 &&
               rect.origin.x < 10000 && rect.origin.y < 10000;
    }

    static void SetCoordinates(CGRect first, CGRect last, TextSelectionInfo &selection) {
        selection.startTop = CGPointMake(first.origin.x, first.origin.y);
        selection.startBottom = CGPointMake(first.origin.x, first.origin.y + first.size.height);
        selection.endTop = CGPointMake(last.origin.x + last.size.width, last.origin.y);
        selection.endBottom = CGPointMake(last.origin.x + last.size.width, last.origin.y + last.size.height);
        selection.posLevel = SelectionPositionLevel::Full;
    }

    bool GetTextViaClipboard(NSRunningApplication *frontApp, TextSelectionInfo &selection) {
        if (!frontApp || frontApp.processIdentifier == running_pid_) return false;
        int64_t newSequence = GetClipboardSequence();
        if (newSequence != clipboard_sequence_) {
            std::string content;
            if (ReadClipboard(content) && !IsTrimmedEmpty(content)) {
                selection.text = content;
                return true;
            }
        }

        clipboard_sequence_ = newSequence;
        ClipboardBackup backup = BackupClipboard();
        if (!SendCopyKey(frontApp.processIdentifier)) return false;
        bool changed = false;
        for (int attempt = 0; attempt < 10; ++attempt) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            newSequence = GetClipboardSequence();
            if (newSequence != clipboard_sequence_) {
                changed = true;
                break;
            }
        }
        if (!changed) {
            if (backup.HasData()) RestoreClipboard(backup);
            clipboard_sequence_ = GetClipboardSequence();
            return false;
        }

        std::string content;
        bool result = ReadClipboard(content) && !IsTrimmedEmpty(content);
        if (result) selection.text = content;
        if (backup.HasData()) RestoreClipboard(backup);
        clipboard_sequence_ = GetClipboardSequence();
        return result;
    }

    static bool SendCopyKey(pid_t pid) {
        CGEventRef down = CGEventCreateKeyboardEvent(nullptr, kVK_ANSI_C, true);
        CGEventRef up = CGEventCreateKeyboardEvent(nullptr, kVK_ANSI_C, false);
        if (!down || !up) {
            if (down) CFRelease(down);
            if (up) CFRelease(up);
            return false;
        }
        CGEventSetFlags(down, kCGEventFlagMaskCommand);
        CGEventSetFlags(up, kCGEventFlagMaskCommand);
        CGEventPostToPid(pid, down);
        std::this_thread::sleep_for(std::chrono::milliseconds(5));
        CGEventPostToPid(pid, up);
        CFRelease(down);
        CFRelease(up);
        return true;
    }

    static LSSelectionPoint Point(CGPoint point) { return {point.x, point.y}; }

    static void Emit(const TextSelectionInfo &selection, LSSelectionCallback callback, void *context) {
        if (!callback) return;
        LSSelectionValue value{
            .text = selection.text.c_str(),
            .bundle_identifier = selection.programName.c_str(),
            .start_top = Point(selection.startTop),
            .start_bottom = Point(selection.startBottom),
            .end_top = Point(selection.endTop),
            .end_bottom = Point(selection.endBottom),
            .mouse_start = Point(selection.mousePosStart),
            .mouse_end = Point(selection.mousePosEnd),
            .method = static_cast<int32_t>(selection.method),
            .position_level = static_cast<int32_t>(selection.posLevel),
            .is_fullscreen = selection.isFullscreen,
        };
        callback(context, &value);
    }

    void ResetGestureState() {
        last_last_mouse_up_pos_ = CGPointZero;
        last_mouse_up_pos_ = CGPointZero;
        last_mouse_down_pos_ = CGPointZero;
        last_mouse_up_time_ = 0;
        last_mouse_down_time_ = 0;
        last_valid_click_ = false;
        last_mouse_down_valid_cursor_ = false;
    }

    LSSelectionCallback callback_ = nullptr;
    void *callback_context_ = nullptr;
    dispatch_queue_t processing_queue_;
    std::atomic<bool> running_{false};
    std::atomic<bool> passive_{false};
    std::atomic<bool> processing_{false};
    std::mutex filter_mutex_;
    FilterMode filter_mode_ = FilterMode::Default;
    std::vector<std::string> filter_list_;
    pid_t running_pid_ = 0;
    int64_t clipboard_sequence_ = 0;

    std::thread event_thread_;
    CFRunLoopRef event_run_loop_ = nullptr;
    std::promise<CFRunLoopRef> event_run_loop_promise_;
    std::future<CFRunLoopRef> event_run_loop_future_;
    CFMachPortRef mouse_event_tap_ = nullptr;
    CFMachPortRef keyboard_event_tap_ = nullptr;
    CFRunLoopSourceRef mouse_source_ = nullptr;
    CFRunLoopSourceRef keyboard_source_ = nullptr;

    CGPoint last_last_mouse_up_pos_ = CGPointZero;
    CGPoint last_mouse_up_pos_ = CGPointZero;
    CGPoint last_mouse_down_pos_ = CGPointZero;
    uint64_t last_mouse_up_time_ = 0;
    uint64_t last_mouse_down_time_ = 0;
    bool last_valid_click_ = false;
    bool last_mouse_down_valid_cursor_ = false;
};

}  // namespace

struct LSSelectionHook {
    NativeSelectionHook implementation;
    LSSelectionHook(LSSelectionCallback callback, void *context) : implementation(callback, context) {}
};

LSSelectionHookRef LSSelectionHookCreate(LSSelectionCallback callback, void *context) {
    try {
        return new LSSelectionHook(callback, context);
    } catch (...) {
        return nullptr;
    }
}

bool LSSelectionHookStart(LSSelectionHookRef hook) { return hook && hook->implementation.Start(); }

void LSSelectionHookStop(LSSelectionHookRef hook) {
    if (hook) hook->implementation.Stop();
}

void LSSelectionHookSetPassive(LSSelectionHookRef hook, bool passive) {
    if (hook) hook->implementation.SetPassive(passive);
}

void LSSelectionHookSetFilter(
    LSSelectionHookRef hook,
    int32_t mode,
    const char *const *bundle_identifiers,
    size_t count
) {
    if (!hook) return;
    FilterMode filterMode = FilterMode::Default;
    if (mode == 1) filterMode = FilterMode::IncludeList;
    if (mode == 2) filterMode = FilterMode::ExcludeList;
    hook->implementation.SetFilter(filterMode, bundle_identifiers, count);
}

bool LSSelectionHookCurrent(LSSelectionHookRef hook, LSSelectionCallback callback, void *context) {
    return hook && hook->implementation.Current(callback, context);
}

void LSSelectionHookDestroy(LSSelectionHookRef hook) { delete hook; }
