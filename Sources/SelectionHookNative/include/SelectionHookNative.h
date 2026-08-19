/**
 * LightSelect C ABI adapter for selection-hook 2.0.3.
 * Upstream: https://github.com/0xfullex/selection-hook @ ff85000e98ab65ab111e2274c385eb3b86c7e19f
 */

#ifndef LIGHTSELECT_SELECTION_HOOK_NATIVE_H
#define LIGHTSELECT_SELECTION_HOOK_NATIVE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LSSelectionHook *LSSelectionHookRef;

typedef struct {
    double x;
    double y;
} LSSelectionPoint;

typedef struct {
    const char *text;
    const char *bundle_identifier;
    LSSelectionPoint start_top;
    LSSelectionPoint start_bottom;
    LSSelectionPoint end_top;
    LSSelectionPoint end_bottom;
    LSSelectionPoint mouse_start;
    LSSelectionPoint mouse_end;
    int32_t method;
    int32_t position_level;
    bool is_fullscreen;
} LSSelectionValue;

typedef void (*LSSelectionCallback)(void *context, const LSSelectionValue *selection);

LSSelectionHookRef LSSelectionHookCreate(LSSelectionCallback callback, void *context);
bool LSSelectionHookStart(LSSelectionHookRef hook);
void LSSelectionHookStop(LSSelectionHookRef hook);
void LSSelectionHookSetPassive(LSSelectionHookRef hook, bool passive);
void LSSelectionHookSetFilter(
    LSSelectionHookRef hook,
    int32_t mode,
    const char *const *bundle_identifiers,
    size_t count
);
bool LSSelectionHookCurrent(LSSelectionHookRef hook, LSSelectionCallback callback, void *context);
void LSSelectionHookDestroy(LSSelectionHookRef hook);

#ifdef __cplusplus
}
#endif

#endif
