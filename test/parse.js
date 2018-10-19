var chai = require('chai');
var expect = require('chai').expect;
var fs = require('fs');
var klaw = require('klaw-sync');
var parse = require('..')().parse;
var path = require('path');

describe('parse', function() {
	var files = klaw(path.join(__dirname, 'fixtures'), {
		nodir: true,
		traverseAll: true,
		filter: function(item) {
			return item.path.slice(-3) === '.ks'
		}
	})

	for(var i = 0; i < files.length; i++) {
		prepare(files[i].path)
	}

	function prepare(file) {
		var root = path.dirname(file)
		var name = path.basename(file).slice(0, -3);
		it(name, function() {
			var source = fs.readFileSync(file, {
				encoding: 'utf8'
			});
			//console.log(source);

			try {
				var error = fs.readFileSync(path.join(root, name + '.error'), {
					encoding: 'utf8'
				});
			}
			catch(error) {
			}

			if(error) {
				var data;

				expect(function() {
					data = parse(source);
				}).to.throw(error);

				expect(data).to.not.exist;
			}
			else {
				var data = parse(source);
				//console.log(JSON.stringify(data, function(key, value){return value == Infinity ? 'Infinity' : value;}, 2));

				var json = fs.readFileSync(path.join(root, name + '.json'), {
					encoding: 'utf8'
				});

				/* expect(data).to.eql(JSON.parse(json, function(key, value) {
					return value === 'Infinity' ? Infinity : value;
				})); */

				// when AST is changed
				data = JSON.parse(JSON.stringify(data, function(key, value){return value == Infinity ? 'Infinity' : key == 'kind' ? 0 : value;}, 2), function(key, value) {
					return value === 'Infinity' ? Infinity : key == 'kind' ? 0 : value;
				});

				expect(data).to.eql(JSON.parse(json, function(key, value) {
					return value === 'Infinity' ? Infinity : key == 'kind' ? 0 : value;
				}));
			}
		});
	}
});