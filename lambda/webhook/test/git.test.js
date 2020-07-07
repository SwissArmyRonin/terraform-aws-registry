const { git } = require('../src/webhook.js');
const util = require('util');
const rimraf = util.promisify(require('rimraf'));
const tmpDirectory = '/tmp/checkout';
const dotenv = require('dotenv');

before(async () => {
    dotenv.config();
})

describe('Git repo operations', () => {
    it('can clone a public repo', async () => {
        await git('mhvelplund/mhrd', 'v1.0.0', tmpDirectory + '/mhrd');
    });
    it('can clone a private repo', async () => {
        await git('mhvelplund/verboten-lands', 'master', tmpDirectory + '/verboten-lands', process.env.USERNAME, process.env.PASSWORD);
    }).timeout(300000);
});

after(async () => {
    await rimraf(tmpDirectory);
})
