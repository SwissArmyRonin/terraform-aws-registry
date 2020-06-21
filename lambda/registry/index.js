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
    if (process.env.DEBUG) {
        console.log('Received event:', JSON.stringify(event));
    }

    let body;
    let statusCode = '200';
    const headers = {
        'Content-Type': 'application/json',
    };

    try {
        switch (event.routeKey) {
            case "GET /modules":
                unimplemented("ListModules", event.pathParameters, event.queryStringParameters);
            case "GET /modules/{namespace}":
                unimplemented("ListModulesNamespace", event.pathParameters, event.queryStringParameters);
            case "GET /modules/search":
                unimplemented("SearchModules", event.pathParameters, event.queryStringParameters);
            case "GET /modules/{namespace}/{name}/{provider}/versions":
                body = await listAvailableVersionsForSpecificModule(event.pathParameters.namespace, event.pathParameters.name, event.pathParameters.provider);
                break;
            case "GET /modules/{namespace}/{name}/{provider}/{version}/download":
                statusCode = 204;
                headers["X-Terraform-Get"] = await downloadSourceCodeForSpecificModuleVersion(event.pathParameters.namespace, event.pathParameters.name, event.pathParameters.provider, event.pathParameters.version);
                body = "";
                break;
            case "GET /modules/{namespace}/{name}":
                unimplemented("ListLatestVersionOfModuleForAllProviders", event.pathParameters, event.queryStringParameters);
            case "GET /modules/{namespace}/{name}/{provider}":
                unimplemented("LatestVersionForSpecificModuleProvider", event.pathParameters, event.queryStringParameters);
            case "GET /modules/{namespace}/{name}/{provider}/{version}":
                unimplemented("GetSpecificModule", event.pathParameters, event.queryStringParameters);
            case "GET /modules/{namespace}/{name}/{provider}/download":
                unimplemented("DownloadLatestVersionOfModule", event.pathParameters, event.queryStringParameters);
            default:
                unimplemented("UnknownRoute", event.pathParameters, event.queryStringParameters);
        }
    } catch (err) {
        if (process.env.DEBUG) {
            console.log(err.toString(), err.stack);
        }
        body = err.toString();
        statusCode = err.statusCode || 500;
    }

    return { statusCode, body, headers };
};


/**
 * Find all versions of a module.
 * 
 * @param {*} namespace 
 * @param {*} name 
 * @param {*} provider 
 */
async function listAvailableVersionsForSpecificModule(namespace, name, provider) {
    const source = `${namespace}/${name}/${provider}`;
    const result = await dynamo.query({
        TableName: process.env.TABLE,
        ScanIndexForward: false,
        KeyConditionExpression: "Id = :v1",
        ExpressionAttributeValues: {
            ":v1": source
        }
    }).promise();

    if (result.Count < 1) {
        const err = new Error("No such module");
        err.statusCode = 404;
        throw err;
    }

    const versions = result.Items.map(i => { return { version: i.Version }; });

    return JSON.stringify({
        modules: [{ source, versions }]
    });
}

/**
 * Get a signed URL to the S3 object with the module.
 * 
 * @param {*} namespace 
 * @param {*} name 
 * @param {*} provider 
 * @param {*} version 
 */
async function downloadSourceCodeForSpecificModuleVersion(namespace, name, provider, version) {
    let params = {
        TableName: process.env.TABLE,
        Key: {
            Id: `${namespace}/${name}/${provider}`,
            Version: `${version}`
        }
    };

    let item = await dynamo.get(params).promise();

    if (!item.Item.Id) {
        const err = new Error("No such module");
        err.statusCode = 404;
        throw err;
    }

    return s3.getSignedUrl('getObject', {
        Bucket: process.env.BUCKET,
        Key: `${namespace}/${name}/${provider}/${version}.zip`,
        Expires: 3600 // 1 hour
    });
}

/**
 * Code that's part of the API, but isn't implemented yet.
 * 
 * @param {*} command 
 * @param {*} pathParameters 
 * @param {*} queryStringParameters 
 */
function unimplemented(command, pathParameters, queryStringParameters) {
    throw new Error(JSON.stringify({
        message: "Not implemented: " + command,
        pathParameters,
        queryStringParameters
    }));
}