import http from 'node:http'

const host = '127.0.0.1'
const port = 18431
const slowDelayMilliseconds = 7000

const json = (response, status, body, method, path) => {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' })
  response.end(JSON.stringify(body))
  console.log(`${method} ${path} ${status}`)
}

const text = (response, status, body, method, path) => {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' })
  response.end(body)
  console.log(`${method} ${path} ${status}`)
}

const server = http.createServer((request, response) => {
  const method = request.method ?? 'GET'
  const path = new URL(request.url ?? '/', `http://${host}:${port}`).pathname
  const match = path.match(/^\/(success|auth|forbidden|rate|server|malformed|empty|slow)\/v1\/(models|chat\/completions)$/)
  if (!match) {
    json(response, 404, { error: 'not_found' }, method, path)
    return
  }

  const [, behavior, resource] = match
  const expectedMethod = resource === 'models' ? 'GET' : 'POST'
  if (method !== expectedMethod) {
    json(response, 405, { error: 'method_not_allowed' }, method, path)
    return
  }

  if (behavior === 'auth') return json(response, 401, { error: 'authentication' }, method, path)
  if (behavior === 'forbidden') return json(response, 403, { error: 'forbidden' }, method, path)
  if (behavior === 'rate') return json(response, 429, { error: 'rate_limit' }, method, path)
  if (behavior === 'server') return json(response, 500, { error: 'server' }, method, path)
  if (behavior === 'malformed') return text(response, 200, '{not-json', method, path)

  const successBody = resource === 'models'
    ? { data: [{ id: 'gpt-fixture-small' }, { id: 'gpt-fixture-large' }, { id: 'gpt-fixture-small' }] }
    : { choices: [{ message: { content: 'OK' } }] }
  const emptyBody = resource === 'models' ? { data: [] } : { choices: [] }
  const body = behavior === 'empty' ? emptyBody : successBody

  if (behavior === 'slow') {
    setTimeout(() => json(response, 200, body, method, path), slowDelayMilliseconds)
    return
  }
  json(response, 200, body, method, path)
})

server.listen(port, host, () => {
  console.log(`MOCK_OPENAI_READY http://${host}:${port}`)
})

const shutdown = () => server.close(() => process.exit(0))
process.on('SIGINT', shutdown)
process.on('SIGTERM', shutdown)
