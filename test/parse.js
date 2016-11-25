var chai = require('chai');
var expect = require('chai').expect;
var fs = require('fs');
var parse = require('../build/parser.js').parse;
var path = require('path');

describe('', function() {
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
			var data = fs.readFileSync(path.join(__dirname, 'fixtures', file), {
				encoding: 'utf8'
			});
			
			try {
				var error = fs.readFileSync(path.join(__dirname, 'fixtures', name + '.error'), {
					encoding: 'utf8'
				});
			}
			catch(error) {
			}
			
			if(error) {
				expect(function() {
					parse(data);
				}).to.throw(error);
			}
			else {
				data = parse(data);
				//console.log(JSON.stringify(data, null, 2));
				
				var json = fs.readFileSync(path.join(__dirname, 'fixtures', name + '.json'), {
					encoding: 'utf8'
				});
				
				expect(data).to.eql(JSON.parse(json, function(key, value) {
					return value === "Infinity"? Infinity : value;
				}));
			}
		});
	}
});