const { clone } = require("isomorphic-git")
const fs = require('fs');
const http = require('isomorphic-git/http/node')
const ignore = require('ignore');
const JSZip = require("jszip");

/**
 * Clone a repo.
 * 
 * @param {string} repo a repo described as 'organization/reponame'
 * @param {string} ref a Git ref. Defaults to 'master'
 * @param {string} dir the checkout directory. Defaults to `/tmp/checkout`
 * @param {string} username an optional username
 * @param {string} password an optional password
 */
exports.git = async (repo, ref, dir, username, password) => clone({
  fs,
  http,
  dir: dir || '/tmp/checkout',
  url: `https://github.com/${repo}.git`,
  ref: ref || 'master',
  singleBranch: true,
  noTags: false,
  depth: 1,
  onAuth: username ? (url) => { return { username, password } } : null
});


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
}

/** Recursively scan folders, adding unfiltered files to the final zip. */
async function zipRecursive(dir, basedir, filter, zip) {
  const dirPath = basedir + '/' + dir;
  const files = fs.readdirSync(dirPath)

  await asyncForEach(files, async (file) => {
    if (!filter.ignores(dir + file)) {
      if (fs.statSync(dirPath + '/' + file).isDirectory()) {
        await zipRecursive(dir ? dir + '/' + file : file, basedir, filter, zip)
      } else {
        zipFileName = `${dir}${dir ? '/' : ''}${file}`
        realFileName = `${dirPath}${dir ? '/' : ''}${file}`
        zip.file(zipFileName, fs.createReadStream(realFileName));
      }
    }
  })
}

/** Loop though promises, waiting for each one. */
async function asyncForEach(array, callback) {
  for (let index = 0; index < array.length; index++) {
    await callback(array[index], index, array);
  }
}
