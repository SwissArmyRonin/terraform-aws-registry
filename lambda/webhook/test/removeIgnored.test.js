const assert = require('assert');
const { git, removeIgnored } = require('../src/webhook.js');
const util = require('util');
const rimraf = util.promisify(require('rimraf'));
const mkdirp = require('mkdirp');
const tmpDirectory = '/tmp/checkout';
const fs = require('fs');

before(async () => {
    await mkdirp(tmpDirectory);
    await git('mhvelplund/mhrd', 'v1.0.0', tmpDirectory);
})

describe('Parsing the .tfignore', () => {
    it('it can read an ignore file', async () => {
        fs.writeFileSync(tmpDirectory + '/.tfignore', `# Ignore the files
# MUX.wire
*.unwired
!BRIEF*
`);

        await removeIgnored(tmpDirectory);

        assert.ok(!fs.existsSync(tmpDirectory + '/RAM64KW16B.unwired'));
        assert.ok(fs.existsSync(tmpDirectory + '/MUX.wire'));
        assert.ok(fs.existsSync(tmpDirectory + '/BRIEFING0.unwired'));
    });
    it('it\'s ok if there is no ignore file', async () => {
        await removeIgnored(tmpDirectory);
    });
});

after(async () => {
    await rimraf(tmpDirectory);
})
