#!/usr/bin/env node

const express = require('express')
const app = express()
const port = process.env.PORT || 3020
const central = process.env.CENTRAL_URL
const apikey = process.env.CENTRAL_API_KEY
const token = process.env.CENTRAL_TOKEN


app.use((req, res, next) => {
    console.log(`${req.ip} ${req.method} ${req.url} ${res.statusCode}`);
    next();
});


async function call_proxy(req, res) {
    try {
        var h1 = {};
        for(k in req.headers) {
            h1[k] = req.headers[k];
        }
        const r = await fetch(`${central}${req.url}`, {method: req.method, headers: h1});
        res.statusCode = r.status;

        const headers = Array.from(r.headers)
                // Be careful about content-encoding header!
                .filter(([key]) => !key.includes('content-encoding'))
                .reduce((headers, [key, value]) => ({[key]: value, ...headers}), {});
        delete headers['X-Server-Dynamic-Streams'];
        headers['X-Config-Server-Separate-Endpoints'] = 'true';
        headers['X-Config-Server-Episodes'] = 'true';
        res.set(headers);

        const body = await r.text();
        res.send(body)
    }
    catch(e) {
        console.error(e)
        res.sendStatus(500)
    }
}

app.get('/central/api/v3/streamers/:hostname/streams', call_proxy)

async function dynamic_streams(req, res) {
    try {
        const r1 = await fetch(`${central}/central/api/v3/streamers`,
            {headers: {'Authorization': `Bearer ${apikey}`}})
        const j1 = await r1.json()
        let streamers = {}
        j1.streamers.forEach(s => {
            streamers[s.hostname] = s.api_url.replace("http://","").replace("/","")
        });

        // const r2 = await fetch(`${central}/central/api/v3/api_tokens/vision`,
        //     {headers: {'Authorization': `Bearer ${apikey}`}})
        // const j2 = await r2.json()
        // const token = j2.key;


        const r = await fetch(`${central}/central/api/v3/streams?name=${req.query.name}`,
        {headers: {'Authorization': `Bearer ${apikey}`}})
        if(r.status != 200) {
            res.sendStatus(r.status)
            return
        }
        const reply = await r.json()
        const streams = reply.streams.map(s => {
            return {
                name: s.name,
                static: false,
                inputs: [{url: `m4s://${streamers[s.layout.ingest]}/${s.name}?token=${token}`}],
                on_play: s.on_play,
            }
        })
        res.json({streams: streams})
    }
    catch (e) {
        console.error(e)
        res.sendStatus(500)
    }
}

app.get('/central/api/v3/streamers/:hostname/dynamic-streams', dynamic_streams);

app.get('/central/api/v3/streamers/:hostname/update-streams', dynamic_streams);

app.get('/central/api/v3/streamers/:hostname/episodes', call_proxy)

app.listen(port, () => {
   console.log(`App running on port ${port}.`)
})
