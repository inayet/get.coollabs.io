require('dotenv').config()
const fastify = require('fastify')({ logger: false, trustProxy: true })
const path = require('path')
const Redis = require('ioredis')
if (!process.env.REDIS_URI) {
  throw new Error('REDIS_URI is not defined')
}
const redis = new Redis(process.env.REDIS_URI)

fastify.register(require('fastify-cors'))
fastify.register(require('fastify-static'), {
  root: path.join(__dirname, 'static'),
})

fastify.get('/', function (req, reply) {
  return reply.sendFile('index.html')
})
fastify.get('/versions.json', async function (req, reply) {
  const appId = req.query.appId
  await redis.set(appId, new Date().getTime())
  return reply.sendFile('versions.json')
})
fastify.get('/instances', async function (req, reply) {
  if (req.headers['cool-api-key'] !== process.env.API_KEY) {
    return reply.redirect('https://coollabs.io')
  }
  const instances = await redis.keys('*')
  return { count: instances.length }
})
fastify.get('/instances/seen', async function (req, reply) {
  if (req.headers['cool-api-key'] !== process.env.API_KEY) {
    return reply.redirect('https://coollabs.io')
  }
  const instances = await redis.keys('*')
  const lastSeen = []
  for (const instance of instances) {
    lastSeen.push({ seen: new Date(Number(await redis.get(instance))) })
  }
  return { lastSeen }
})

const start = async () => {
  try {
    await fastify.listen(3000, '0.0.0.0')
    console.log(`API listening on ${fastify.server.address().port}.`)
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}
start()
