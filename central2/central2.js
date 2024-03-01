#!/usr/bin/env node

const express = require('express')
const app = express()
const port = process.env.PORT || 3020
const central = process.env.CENTRAL_URL

app.get('/streamer/api/v3/streamers/:hostname/streams', (req, res) => {
    res.send(req.params)
})

app.get('/streamer/api/v3/streamers/:hostname/dynamic-streams', (req, res) => {
    res.send(req.params)
})

app.get('/streamer/api/v3/streamers/:hostname/update-streams', (req, res) => {
    res.send(req.params)
})

app.get('/streamer/api/v3/streamers/:hostname/episodes', (req, res) => {
    res.send(req.params)
})

app.listen(port, () => {
   console.log(`App running on port ${port}.`)
})
