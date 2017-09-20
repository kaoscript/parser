require('kaoscript/register')

var fs = require('fs');
var parse = require('.')().parse;
var path = require('path');

var files = fs.readdirSync(path.join(__dirname, 'test', 'fixtures'));

var file;
for(var i = 0; i < files.length; i++) {
	file = files[i];
	
	if(file.slice(-3) === '.ks') {
		prepare(file);
	}
}
	
function prepare(file) {
	var name = file.slice(0, -3);
	var data = fs.readFileSync(path.join(__dirname, 'test', 'fixtures', file), {
		encoding: 'utf8'
	});
	
	try {
		var error = fs.readFileSync(path.join(__dirname, 'test', 'fixtures', name + '.error'), {
			encoding: 'utf8'
		});
	}
	catch(error) {
	}
	
	if(error) {
		try {
			parse(data);
		}
		catch(error) {
		}
	}
	else {
		try {
			data = parse(data);
			
			var json = fs.writeFileSync(
				path.join(__dirname, 'test', 'fixtures', name + '.json'),
				JSON.stringify(data, function(key, value) {
					if(value == Infinity) {
						return 'Infinity';
					}
					return value;
				}, 2), {
					encoding: 'utf8'
				}
			);
		}
		catch(error) {
		}
	}
}