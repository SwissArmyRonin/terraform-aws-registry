//const util = require('util');
// const AWS = require('aws-sdk');
// const dynamo = new AWS.DynamoDB.DocumentClient();
// const s3 = new AWS.S3();

const {git} = require("./src/webhook")

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
        validateHmac(event.headers, event.body);
        const request = JSON.parse(event.body);

        // Process request
        if (request.ref_type != "tag") {
            const err = new Error("Not a new tag event");
            err.statusCode = 400;
            throw err;
        }

        const full_name = request.repository.full_name
        const ref = request.ref;

        await git(full_name, ref); // TODO: add username/password

        body = "OK";
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

/**
 * Validate HMAC header.
 * 
 * @param {*} headers 
 * @param {*} body 
 */
function validateHmac(headers, body) {
    const xHubSignature = headers['x-hub-signature'];
    let expected;
    try {
        expected = "sha1=" + require('crypto').createHmac('sha1', process.env.GITHUB_SECRET).update(body).digest('hex');
    } catch (err) {
        expected = "ERROR"; // This causes a signature validation error below
    }

    if (xHubSignature != expected) {
        if (process.env.DEBUG) {
            console.log('xHubSignature', xHubSignature);
            console.log('expected', expected);
        }
        const err = new Error("Invalid signature header");
        err.statusCode = 401;
        throw err;
    }
}