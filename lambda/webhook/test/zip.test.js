const { git, zip } = require('../src/webhook.js');
const util = require('util');
const rimraf = util.promisify(require('rimraf'));
const path = require('path');
const os = require('os');
const fs = require('fs');
const fsPromises = fs.promises; 

let tmpDirectory;

before(async () => {
    tmpDirectory = await fsPromises.mkdtemp(path.join(os.tmpdir(), 'checkout-'))
    await git('mhvelplund/mhrd', 'v1.0.0', tmpDirectory);
})

describe('Zip', () => {
    it('can zip everything except ignored files', async () => {
        fs.writeFileSync(tmpDirectory + '/.tfignore', `# Ignore the files
# MUX.wire
*.unwired
!BRIEF*
`);

        console.log(await zip(tmpDirectory))
        // TODO: assert that zip creation succeeds
    });
});

after(async () => {
    await rimraf(tmpDirectory);
})
