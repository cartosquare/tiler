// options
var options = require('./config/settings.js').options;
var restify = require('restify');
var fs = require('fs');
var gmap = require('./lib/gmap.node');

// Init log
console.log("log level: " + options.logLevel || 6);
gmap.initLog(options.logLevel || 6);//, __dirname + '/log');

// register font
gmap.registerFonts(options.mapDir + "/fonts");

// data source pool
console.log("Connect SQL datasource " + options.osmConn.url + " ...");
gmap.registerPool(options.osmConn.name, options.osmConn.url, options.osmConn.initialConnSize, options.osmConn.maxConnSize, "PG");

// seaweed storage
console.log("Resgist weed storage " + options.weed.host + ":" + options.weed.port + " ...")
gmap.registerStorage(options.weed.host, options.weed.port);

// load lod
var lod = fs.readFileSync(__dirname + '/map/lod.json', 'utf-8');

// vt def
var vtDef = fs.readFileSync(__dirname + '/map/vt.json', 'utf-8');

// load def
var def = {};
var def_schema = require(__dirname + '/map/tile.json');
def.background_color = def_schema.background_color;
def.icon = def_schema.icon;

def.data_sources = {};
for (var ds of def_schema.data_sources_files) {
    console.log('load datasource schema: ' + ds);
    
    var datasource = require(__dirname + '/map/includes/' + ds);
    
    for (var dds in datasource.data_sources) {
        def.data_sources[dds] = datasource.data_sources[dds];
    }
}

def.layers = {};
for (var layers of def_schema.layers_files) {
    console.log('load layer schema: ' + layers);
    
    var lys = require(__dirname + '/map/includes/' + layers);
    for (var llys in lys.layers) {
        if (lys.layers[llys].style_files) {
            var tmpLayer = lys.layers[llys];
            tmpLayer.rules = [];
            
            var styles = tmpLayer.style_files;
            for (var sty of styles) {
                var sty_json = require(__dirname + '/map/includes/' + sty);
                
                for (rule of sty_json.rules) {
                   tmpLayer.rules.push(rule);
                }
            }
            delete tmpLayer.style_files;
            def.layers[llys] = tmpLayer;
        } else {
            def.layers[llys] = lys.layers[llys];
        }
        
    }
}


function style(req, res, next) {
    var params = req.params;
    var styles = params.styles;
   
    var map_dir = __dirname + '/user-maps/' + params.key;
    if (!fs.existsSync(map_dir)) {
        fs.mkdirSync(map_dir);
    }
    
    for (name in styles) {
        fs.writeFileSync(map_dir + '/class-' + name + '.json', styles[name], 'utf-8');
    }

    res.json({status: "ok"});
    return next();
}

function _getVtPath(name, z, x, y) {
    return '/' + name + '/' + z + '/' + x + '/' + y + '/.pb';
}

function genTile(opts, req, res, next) {
    console.log('generate tile ');
    
    opts.saveCloud = false;
    opts.renderType = 0;
    gmap.tile(opts, function(err, stream) {
        if (err) {
            return next(new restify.InternalServerError('render tile fail!'));
        } else {
            res.end(stream, 'binary');
        }
    });
}

function getTile(req, res, next) {
    var params = req.params;

    var name = "osm";
    var z = parseInt(params.z) || 0;
    var x = parseInt(params.x) || 0;
    var y = parseInt(params.y) || 0;

    var vtPath = _getVtPath(name, z, x, y);
    console.log('Get vector-tile at ' + vtPath);

    var key = params.key;
    console.log('key: ' + key);
    var includeDir = __dirname + '/map/includes/';
    if (fs.existsSync(__dirname + '/user-maps/' + key)) {
        includeDir = __dirname + '/user-maps/';
    }
    
    var userDef = def;
    userDef.classes = {};
    for (var clazz of def_schema.classes_files) {
        var clz = require(includeDir + clazz);
        for (var clzz in clz.classes) {
            userDef.classes[clzz] = clz.classes[clzz];
        }
    }
    
    //fs.writeFileSync('test.json', JSON.stringify(userDef), 'utf-8');
    
    var opts = {
        mapDir: options.mapDir,
        lod: lod,
        style: vtDef,
        fromFile: false,
        renderType: 2, // render vector tile
        z: z,
        x: x,
        y: y,
        bufferSize: 32,
        renderLabel: true,
        saveCloud: true,
        tileURL: vtPath
    };

    gmap.getFile(vtPath, function(err, data) {
        console.log('gmap.getFile result: ' + err);
        err = err || !data || data.length == 0;

        if (err) {
            console.log('regenerate vector tile...');
            gmap.tile(opts, function(err, stream) {
                if (err) {
                    return next(new restify.InternalServerError('render vector tile fail!'));
                } else {
                    console.log('regenerate vector tile success.');
                    opts.style = JSON.stringify(userDef);
                    genTile(opts, req, res, next);
                }
            });
        } else {
            console.log('vector tile exists');
            opts.style = JSON.stringify(userDef);
            genTile(opts, req, res, next);
        }
    });
}

exports.getTile = getTile;
exports.style = style;