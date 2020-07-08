const AWS = require('aws-sdk');
const dynamo = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();

const path = require('path');
const os = require('os');
const fs = require('fs');
const fsPromises = fs.promises;
const { git, zip, validateHmac } = require('./src/webhook');

/**
 * Terraform registry implementation.
 *
 * @param {*} event
 * @param {*} context
 */
exports.handler = async (event, context) => {
	if (process.env.DEBUG) {
		console.log('Received event:', JSON.stringify(event));
	}

	let body;
	let statusCode = '200';

	try {
		await validateHmac(event.headers, event.body);
		const request = JSON.parse(event.body);

		// Process request
		if (request.ref_type != 'tag') {
			const err = new Error('Not a new tag event');
			err.statusCode = 400;
			throw err;
		}

		const full_name = request.repository.full_name;
		const ref = request.ref;

		const tempDir = await fsPromises.mkdtemp(path.join(os.tmpdir(), 'checkout-'));
		await git(full_name, ref, tempDir); // TODO: add username/password
		const zipFile = await zip(tempDir);

		// Upload the zip file to S3
		const data = fs.readFileSync(zipFile);
		let version = ref.replace(/^[^0-9]*/, '');
		if (version.length == 0) {
			version = '0.0.0';
		}
		const s3Key = `${full_name}/aws/${version}.zip`;

		await s3
			.putObject({
				Body: Buffer.from(data, 'binary'),
				Bucket: process.env.BUCKET,
				Key: s3Key
			})
			.promise();

		if (process.env.DEBUG) {
			console.log(`Zip file uploaded: ${zipFile} -> ${process.env.BUCKET}/${s3Key}`);
		}

		// Update dynamo registry
		await dynamo
			.put({
				TableName: process.env.TABLE,
				Item: {
					Id: `${full_name}/aws`,
					Version: version
				}
			})
			.promise();

		body = 'OK';
	} catch (err) {
		if (process.env.DEBUG) {
			console.log(err.toString(), err.stack);
		}
		body = err.message;
		statusCode = err.statusCode || 500;
	}

	const headers = { 'Content-Type': 'application/json' };

	return { statusCode, body, headers };
};
