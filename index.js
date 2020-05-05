const express = require('express');
const app = express();
const mysql = require('mysql2/promise');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const mime = require('mime-types');
const { spawn } = require('child_process');
const fileUpload = require('express-fileupload');
const config = require('./config');
const fs = require('fs-extra');
const moment = require('moment');
const cors = require('cors');

app.use(cors());
app.use(bodyParser.urlencoded({
    extended: false,
}));

// parse application/json
app.use(bodyParser.json());

app.use(fileUpload({
    limits: { fileSize: 50 * 1024 * 1024 },
}));

// create the connection to database
const connection = mysql.createPool({
    host: config.db.host,
    user: config.db.user,
    password: config.db.password,
    database: config.db.database,
});

/* Hook to get finish processed video */
app.get('/done/:id/:duration', async (req, res) => {
    if (!req.params.id || !req.params.duration) {
        return res.send({ error: 'No movie id or duration.' });
    }

    console.log(req.params.id, req.params.duration);

    const duration = moment(req.params.duration.split('.')[0], 'HH:mm:ss').format('YYYY-MM-DD HH:mm:ss');

    const [movies, ] = await connection.execute('SELECT * FROM `online_movies` WHERE `server_id` = ?', [req.params.id]);

    if (movies.length != 1) {
        return res.send({ error: 'Not found' });
    }

    
    if (movies[0].status != 'processing') {
        return res.send({ error: 'Something bad' });
    }
    console.log(movies[0]);

    const [rows, ] = await connection.execute('UPDATE `online_movies` SET `status` = "done", duration = ? WHERE `server_id` = ?', [duration, req.params.id]);

    res.sendStatus(200);
});

app.post('/transcode', async (req, res) => {
    /* Start the processing */
    if (!req.files) {
        return res.send({error: 'No data'});
    }
    const { files: { file } } = req;

    if (!file) {
        return res.send({ error: 'No input file received. Please send video file in file in application/form-data format.' });
    }
    const { data, name, encoding, mimetype, size } = file;
    const extension = mime.extension(mimetype);
    /**
     * Check for extension
     */
    if (!extension || !config.streaming.extensions.includes(extension)) {
        return res.send({ error: 'Video format is not supported.' });
    }
    // generare the unique id for this video.
    const videoId = uuidv4();

    const [movies, ] = await connection.execute('SELECT * FROM `online_movies` WHERE `server_id` = ?', [videoId]);

    if (movies.length != 0) {
        return res.send({ error: 'Someone allready in' });
    }

    const [rows, ] = await connection.execute('INSERT INTO `online_movies` (`name`, `path`, `duration`, `available`, `server_id`, `status`) VALUES (?, ?, ? ,? ,?, ?)', 
        [name.replace(`.${extension}`, ''), videoId, 0, false, videoId, 'processing']);

    /**
     * Save the incoming file in uploads folder
     */
    fs.mkdirSync(path.resolve(__dirname, config.streaming.uploads.path, videoId));
    const videoFilePath = path.resolve(__dirname, config.streaming.uploads.path, videoId, `${videoId}.${extension}`);
    fs.writeFileSync(videoFilePath, data);

    // exec(`.././create-hls-vod.sh ${videoId} ${extension} ${S3_BUCKET}`);
    const createHLSVOD = spawn('bash', ['process.sh', videoId, extension, `${config.static.url}/static/cinema/${videoId}`]);
    createHLSVOD.stdout.on('data', d => console.log(`stdout info: ${d}`));
    createHLSVOD.stderr.on('data', d => console.log(`stderr error: ${d}`));
    createHLSVOD.on('error', d => console.log(`error: ${d}`));
    createHLSVOD.on('close', code => console.log(`child process ended with code ${code}`));
    res.send('success');
});

const port = 80;
app.listen(port, () => console.log(`Server listening on port ${port}!`));






