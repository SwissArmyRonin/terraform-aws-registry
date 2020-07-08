const AWS = require('aws-sdk');
const ssm = new AWS.SSM();

const { clone } = require('isomorphic-git');
const fs = require('fs');
const http = require('isomorphic-git/http/node');
const ignore = require('ignore');
const JSZip = require('jszip');

/**
 * Clone a repo.
 *
 * @param {string} repo a repo described as 'organization/reponame'
 * @param {string} ref a Git ref. Defaults to 'master'
 * @param {string} dir the checkout directory. Defaults to `/tmp/checkout`
 * @param {string} username an optional username
 * @param {string} password an optional password
 */
exports.git = async (repo, ref, dir) => {
	let username;
	const key = `access_token/${repo.split('/')[0]}`;

	try {
		username = await getSsm(key);
	} catch (err) {
		// Ignore
	}

	clone({
		fs,
		http,
		dir: dir || '/tmp/checkout',
		url: `https://github.com/${repo}.git`,
		ref: ref || 'master',
		singleBranch: true,
		noTags: false,
		depth: 1,
		onAuth: (url) => {
			return { username };
		}
	});
};

/**
 * Zip the checkout folder, minus the ignored files.
 *
 * @param {string} dir the checkout directory. Defaults to `/tmp/checkout`
 * @return {string} the path of the output zip file
 */
exports.zip = async (dir) => {
	const filename = dir + '/.tfignore';
	const filter = ignore();

	if (fs.existsSync(filename)) {
		filter.add(fs.readFileSync(filename).toString());
	}

	filter.add('.git*');
	filter.add('.tfignore');

	const zip = new JSZip();
	await zipRecursive('', dir, filter, zip);
	const data = await zip.generateAsync({
		type: 'uint8array',
		compression: 'DEFLATE',
		platform: process.platform
	});

	const zipName = dir + '/output.zip';
	fs.writeFileSync(zipName, data);

	return zipName;
};

/** Recursively scan folders, adding unfiltered files to the final zip. */
async function zipRecursive(dir, basedir, filter, zip) {
	const dirPath = basedir + '/' + dir;
	const files = fs.readdirSync(dirPath);

	await asyncForEach(files, async (file) => {
		if (!filter.ignores(dir + file)) {
			if (fs.statSync(dirPath + '/' + file).isDirectory()) {
				await zipRecursive(dir ? dir + '/' + file : file, basedir, filter, zip);
			} else {
				const zipFileName = `${dir}${dir ? '/' : ''}${file}`;
				const realFileName = `${dirPath}${dir ? '/' : ''}${file}`;
				zip.file(zipFileName, fs.createReadStream(realFileName));
			}
		}
	});
}

/** Loop though promises, waiting for each one. */
async function asyncForEach(array, callback) {
	for (let index = 0; index < array.length; index++) {
		await callback(array[index], index, array);
	}
}

/**
 * Validate HMAC header.
 *
 * @param {*} headers
 * @param {*} body
 */
exports.validateHmac = async (headers, body) => {
	const xHubSignature = headers['x-hub-signature'];
	let expected;

	const githubSecret = await getSsm('github_secret');

	try {
		expected = 'sha1=' + require('crypto').createHmac('sha1', githubSecret).update(body).digest('hex');
	} catch (err) {
		expected = 'ERROR'; // This causes a signature validation error below
	}

	if (xHubSignature != expected) {
		if (process.env.DEBUG) {
			console.log('xHubSignature', xHubSignature);
			console.log('expected', expected);
		}
		const err = new Error('Invalid signature header');
		err.statusCode = 401;
		throw err;
	}
};

/**
 * Find the value of an SSM key with the prefix from `process.env.SSM_PREFIX`.
 * @param {string} key a path, e.g. "github_secret"
 */
async function getSsm(key) {
	const param = await ssm
		.getParameter({
			Name: `/${process.env.SSM_PREFIX}/${key}`,
			WithDecryption: true
		})
		.promise();

	return param.Parameter.Value;
}
