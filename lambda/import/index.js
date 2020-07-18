console.log('Loading function');

exports.handler = async (event) => {
	console.log('EVENT:', event);
	const p = event.pathParameters || {};
	const body = {
		modulepath: `${p.organization}/${p.repository}/aws`,
		versions: [p.ref]
	};

	return { statusCode: 200, body: JSON.stringify(body), headers: null };
};
