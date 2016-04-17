// 配置参数
exports.options = {
    port: 3040,
    mapDir:  '/var/geohey/mapping',
    osmConn: {
        name: 'osm',
        url: 'PG:dbname=osm host=localhost port=5432 user=gis',
        initialConnSize: 5,
        maxConnSize: 15
    },
    
    weed: {
        host: 'localhost',
        port: '8889'
    },
    
    logLevel: 2
}
