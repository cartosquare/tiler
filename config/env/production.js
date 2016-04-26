// 配置参数
exports.options = {
    port: 3040,
    mapDir:  '/root/cartosquare-tiler/map',
    osmConn: {
        name: 'osm',
        url: 'PG:dbname=osm host=localhost port=5432 user=gis',
        initialConnSize: 5,
        maxConnSize: 15,
        open: false
    },
    
    weed: {
        host: 'localhost',
        port: '8889'
    },
    
    logLevel: 2
}
