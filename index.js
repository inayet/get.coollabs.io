const fastify = require('fastify')({ logger: true })
const path = require('path')

fastify.register(require('fastify-cors'))
fastify.register(require('fastify-static'), {
  root: path.join(__dirname, 'static'),
})

fastify.get('/', function (req, reply) {
  return reply.sendFile('index.html')
})

const start = async () => {
  try {
    await fastify.listen('0.0.0.0', 3000)
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}
start()