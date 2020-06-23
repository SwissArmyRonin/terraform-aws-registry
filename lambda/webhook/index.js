const AWS = require('aws-sdk');

const dynamo = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();

/**
 * Terraform registry implementation.
 * 
 * @param {*} event 
 * @param {*} context 
 */
exports.handler = async (event, context) => {
        console.log('Received event:', JSON.stringify(event));

    let body = JSON.stringify(event)
    let statusCode = '200';
    const headers = {
        'Content-Type': 'application/json',
    };

    return { statusCode, body, headers };
};