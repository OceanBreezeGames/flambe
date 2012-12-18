//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.swf;

import haxe.Json;

import flambe.asset.AssetPack;
import flambe.display.Sprite;
import flambe.swf.Format;

using flambe.util.Strings;

/**
 * An exported Flump library containing movies and bitmaps.
 */
class Library
{
    /**
     * The original frame rate of movies in this library.
     */
    public var frameRate (default, null) :Float;

    /**
     * Creates a library using files in an AssetPack.
     * @param baseDir The directory in the pack containing Flump's library.json and texture atlases.
     */
    public function new (pack :AssetPack, baseDir :String)
    {
        _symbols = new Hash();

        var reader :Format = Json.parse(pack.getFile(baseDir + "/library.json"));

        frameRate = reader.frameRate;

        var movies = [];
        for (movieObject in reader.movies) {
            var movie = new MovieSymbol(this, movieObject);
            movies.push(movie);
            _symbols.set(movie.name, movie);
        }

        var atlases;
        if (reader.textureGroups != null) {
            var groups = reader.textureGroups;
            if (groups[0].scaleFactor != 1 || groups.length > 1) {
                Log.warn("Flambe doesn't support Flump's Additional Scale Factors. " +
                    "Use Base Scales and load from different asset packs instead.");
            }
            atlases = groups[0].atlases;
        } else {
            // Support older Flump versions that don't have textureGroups
            atlases = (untyped reader).atlases;
        }
        for (atlasObject in atlases) {
            var atlas = pack.getTexture(baseDir + "/" + atlasObject.file.removeFileExtension());
            for (textureObject in atlasObject.textures) {
                var bitmap = new BitmapSymbol(textureObject, atlas);
                _symbols.set(bitmap.name, bitmap);
            }
        }

        // Now that all symbols have been parsed, go through keyframes and resolve references
        for (movie in movies) {
            for (layer in movie.layers) {
                for (kf in layer.keyframes) {
                    var symbol = _symbols.get(kf.symbolName);
                    if (symbol != null) {
                        if (layer.lastSymbol == null) {
                            layer.lastSymbol = symbol;
                        } else if (layer.lastSymbol != symbol) {
                            layer.multipleSymbols = true;
                        }
                        kf.symbol = symbol;
                    }
                }
            }
        }
    }

    /**
     * Retrieve a name symbol from this library, or null if not found.
     */
    inline public function getSymbol (symbolName :String) :Symbol
    {
        return _symbols.get(symbolName);
    }

    /**
     * Creates a sprite from a symbol name, it'll either be a movie or a bitmap.
     * @param required If true and the symbol is not in this library, an error is thrown.
     */
    public function createSprite (symbolName :String, required :Bool = true) :Sprite
    {
        var symbol = _symbols.get(symbolName);
        if (symbol == null) {
            if (required) {
                throw "Missing symbol".withFields(["name", symbolName]);
            }
            return null;
        }
        return symbol.createSprite();
    }

    /**
     * Creates a movie sprite from a symbol name.
     * @param required If true and the symbol is not in this library, an error is thrown.
     */
    inline public function createMovie (symbolName :String, required :Bool = true) :MovieSprite
    {
        return cast createSprite(symbolName, required);
    }

    /**
     * Iterates over all the symbols in this library.
     */
    inline public function iterator () :Iterator<Symbol>
    {
        return _symbols.iterator();
    }

    private var _symbols :Hash<Symbol>;
}
