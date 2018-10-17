var chai = require('chai');
var expect = require('chai').expect;
var fs = require('fs');
var parse = require('..')().parse;
var path = require('path');

describe('parse', function() {
	var files = fs.readdirSync(path.join(__dirname, 'fixtures'));

	var file;
	for(var i = 0; i < files.length; i++) {
		file = files[i];

		if(file.slice(-3) === '.ks') {
			prepare(file);
		}
	}

	function prepare(file) {
		var name = file.slice(0, -3);
		it(name, function() {
			var source = fs.readFileSync(path.join(__dirname, 'fixtures', file), {
				encoding: 'utf8'
			});
			//console.log(source);

			try {
				var error = fs.readFileSync(path.join(__dirname, 'fixtures', name + '.error'), {
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

				var json = fs.readFileSync(path.join(__dirname, 'fixtures', name + '.json'), {
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