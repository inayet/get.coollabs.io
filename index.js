require('dotenv').config()
const fastify = require('fastify')({ logger: true, trustProxy: true })
const path = require('path')
const fs = require('fs').promises

const crypto = require('crypto');
const algorithm = 'aes-256-ctr';
const secretKey = process.env.ENCRYPT_KEY;
const iv = process.env.IV

fastify.register(require('fastify-cors'))
fastify.register(require('fastify-static'), {
  root: path.join(__dirname, 'static'),
})

fastify.get('/', function (req, reply) {
  return reply.sendFile('index.html')
})
fastify.get('/version.json', async function (req, reply) {
  const { type } = req.query
  if (type) {
    const json = JSON.parse(await (await fs.readFile('./instances.json', { encoding: 'utf-8' })))
    const set = new Set(json.instances)
    const cipher = crypto.createCipheriv(algorithm, secretKey, iv);
    const encryptedIP = Buffer.concat([cipher.update(req.ip), cipher.final()]).toString('hex');

    if (!set.has(encryptedIP)) {
      set.add(encryptedIP)
    }
    json.count = set.size;
    json.instances = Array.from(set)
    await fs.writeFile('./instances.json', JSON.stringify(json))
  }

  return reply.sendFile('version.json')
})

const start = async () => {
  try {
    await fastify.listen(3000, '0.0.0.0')
  } catch (err) {
    fastify.log.error(err)
    process.exit(1)
  }
}
start()