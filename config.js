const path = require('path');

let host = process.env.HOST_IP;

let config = {
    static: {
        url: `http://${host}:8082`,
    },
    db: {
        host: 'db',
        user: 'root',
        password: 'root',
        database: 'idp',
    },
    streaming: {
        url: `http://${host}:8083`,
        uploads: {
            path: 'uploads',
        },
        target: {
            path: 'cinema',
        },
        extensions: [
            // MP4
            'mp4',
            'm4a',
            'm4v',
            'f4v',
            'f4a',
            'm4b',
            'm4r',
            'f4b',
            'mov',
            // 3GP
            '3gp',
            '3gp2',
            '3g2',
            '3gpp',
            '3gpp2',
            // OGG
            'ogg',
            'oga',
            'ogv',
            'ogx',
            // WMV
            'wmv',
            'wma',
            'asf',
            // WEBM
            'webm',
            // FLV
            'flv',
            // AVI
            'avi',
            // Quicktime
            'qt',
            // HDV
            'hdv',
            // MXF
            'OP1a',
            'OP-Atom',
            // MPEG-TS
            'ts',
            'mts',
            'm2ts',
            // WAV
            'wav',
            // Misc
            'lxf',
            'gxf',
            'vob',
        ],
    },
};


module.exports = config;