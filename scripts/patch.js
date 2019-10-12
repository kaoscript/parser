require('kaoscript/register')

var fs = require('fs');
var klaw = require('klaw-sync');
var parse = require('..')().parse;
var path = require('path');

var files = klaw(path.join(__dirname, '..', 'test', 'fixtures'), {
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
	var data = fs.readFileSync(file, {
		encoding: 'utf8'
	});

	try {
		var error = fs.readFileSync(path.join(root, name + '.error'), {
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

			data = JSON.stringify(data, function(key, value) {
				if(value === Infinity) {
					return 'Infinity';
				}
				return value;
			}, 2);

			fs.writeFileSync(path.join(root, name + '.json'), data, {
				encoding: 'utf8'
			});
		}
		catch(error) {
		}
	}
}