const { git, zip } = require('../src/webhook.js');
const util = require('util');
const rimraf = util.promisify(require('rimraf'));
const tmpDirectory = '/tmp/checkout';
const fs = require('fs');

before(async () => {
    await git('mhvelplund/mhrd', 'v1.0.0', tmpDirectory);
})

describe('Zip', () => {
    it('can zip everything except ignored files', async () => {
        fs.writeFileSync(tmpDirectory + '/.tfignore', `# Ignore the files
# MUX.wire
*.unwired
!BRIEF*
`);

        await zip(tmpDirectory);
        // TODO: assert that zip creation succeeds
    });
});

after(async () => {
    await rimraf(tmpDirectory);
})
