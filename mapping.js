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
if (options.osmConn.open) {
    console.log("Connect SQL datasource " + options.osmConn.url + " ...");
    gmap.registerPool(options.osmConn.name, options.osmConn.url, options.osmConn.initialConnSize, options.osmConn.maxConnSize, "PG");
}

// seaweed storage
console.log("Resgist weed storage " + options.weed.host + ":" + options.weed.port + " ...")
gmap.registerStorage(options.weed.host, options.weed.port);

// load lod
var lod = fs.readFileSync(__dirname + '/map/lod.json', 'utf-8');

// vt def
var vtDef = fs.readFileSync(__dirname + '/map/vt.json', 'utf-8');

// load def
var def = {};
var def_schema = JSON.parse(fs.readFileSync(__dirname + '/map/tile.json', 'utf-8'));
def.background_color = def_schema.background_color;
def.icon = def_schema.icon;

def.data_sources = {};
var has_cloud_source = false;
for (var ds of def_schema.data_sources_files) {
    console.log('load datasource schema: ' + ds);

    var datasource = JSON.parse(fs.readFileSync(__dirname + '/map/includes/' + ds, 'utf-8'));

    for (var dds in datasource.data_sources) {
        def.data_sources[dds] = datasource.data_sources[dds];
        if (datasource.data_sources[dds].type = 'cloud_vector_tile') {
            has_cloud_source = true;
        }
    }
}

def.classes = {};
loadClasses(def, __dirname + '/map/includes/');

def.layers = {};
var layersMap = {};
for (var layers of def_schema.layers_files) {
    var lys = JSON.parse(fs.readFileSync(__dirname + '/map/includes/' + layers, 'utf-8'));
    layersMap[layers] = lys;
    
    loadLayers(def, lys.layers);
}

//fs.writeFileSync('def.json', JSON.stringify(def), 'utf-8');

function loadLayers(obj, layers) {
    for (var llys in layers) {
        if (layers[llys].style_files) {
            var tmpLayer = layers[llys];
            tmpLayer.rules = [];
            
            var styles = tmpLayer.style_files;
            for (var sty of styles) {
                var sty_json = JSON.parse(fs.readFileSync(__dirname + '/map/includes/' + sty, 'utf-8'));
                
                for (rule of sty_json.rules) {
                   tmpLayer.rules.push(rule);
                }
            }
            delete tmpLayer.style_files;
            obj.layers[llys] = tmpLayer;
        } else {
            obj.layers[llys] = layers[llys];
        }
    }
}

function loadClasses(obj, includeDir) {
    for (var clazz of def_schema.classes_files) {
            var clz;
            if (clazz == 'class-lod.json') {
                clz = JSON.parse(fs.readFileSync(__dirname + '/map/includes/' + clazz, 'utf-8'));
            } else {
                clz = JSON.parse(fs.readFileSync(includeDir + clazz, 'utf-8'));
            }

            for (var clzz in clz.classes) {
                obj.classes[clzz] = clz.classes[clzz];
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
        var filename = map_dir + '/class-' + name + '.json';
        if (fs.existsSync(filename)) {
            fs.unlinkSync(filename);
        }
        
        fs.writeFileSync(filename, styles[name], 'utf-8');
    }

    res.json({status: "ok"});
    return next();
}

function _getVtPath(name, z, x, y) {
    return '/' + name + '/' + z + '/' + x + '/' + y + '/.pb';
}

function genTile(opts, req, res, next) {
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
    var retina = parseInt(params.retina) || 1;
    
    var vtPath = _getVtPath(name, z, x, y);

    var key = params.key;
    var includeDir = __dirname + '/map/includes/';
    var userIncludeDir = __dirname + '/user-maps/' + key + '/';
    var userDef = {};
    if (fs.existsSync(userIncludeDir)) {
        includeDir = userIncludeDir;
        // top file
        var topFile = JSON.parse(fs.readFileSync(includeDir + 'class-top.json', 'utf-8'));
        
        // global style
        userDef.background_color = topFile.background_color;
        userDef.icon = topFile.icon;
       
        userDef.classes = {};
        loadClasses(userDef, includeDir);
        
        userDef.data_sources = def.data_sources;

        userDef.layers = {};
        for (var layers of topFile.layers_files) {
            
            var key = "layers-" + layers + ".json";
            loadLayers(userDef, layersMap[key].layers);
            console.log('load layer: ' + key);
        }
    } else {
        userDef = def;
    }

    //fs.writeFileSync('test.json', JSON.stringify(userDef), 'utf-8');

    if (has_cloud_source) {
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
            tileURL: vtPath,
            retinaFactor: retina
        };

        gmap.getFile(vtPath, function (err, data) {
            err = err || !data || data.length == 0;

            if (err) {
                gmap.tile(opts, function (err, stream) {
                    if (err) {
                        return next(new restify.InternalServerError('render vector tile fail!'));
                    } else {
                        opts.style = JSON.stringify(userDef);
                        genTile(opts, req, res, next);
                    }
                });
            } else {
                opts.style = JSON.stringify(userDef);
                genTile(opts, req, res, next);
            }
        });
    } else {
        var opts = {
            mapDir: options.mapDir,
            lod: lod,
            style: JSON.stringify(userDef),
            fromFile: false,
            renderType: 0, // render png tile
            z: z,
            x: x,
            y: y,
            bufferSize: 32,
            renderLabel: true,
            saveCloud: false,
            retinaFactor: retina
        };

        gmap.tile(opts, function (err, stream) {
            if (err) {
                return next(new restify.InternalServerError('render tile fail!'));
            } else {
                res.end(stream, 'binary');
            }
        });
    }
}

exports.getTile = getTile;
exports.style = style;