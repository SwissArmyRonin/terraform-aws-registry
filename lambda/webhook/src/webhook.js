const { clone } = require("isomorphic-git")
const fs = require('fs');
const http = require('isomorphic-git/http/node')
const ignore = require('ignore');
const util = require('util');
const rimraf = util.promisify(require('rimraf'));

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
 * Remove ignored files.
 * 
 * @param {string} dir the checkout directory. Defaults to `/tmp/checkout`
 */
exports.removeIgnored = async (dir) => {
  const filename = dir + '/.tfignore';

  if (!fs.existsSync(filename)) return;

  const filter = ignore().add(fs.readFileSync(filename).toString());
  filter.add('.git*');
  filter.add('.tfignore');
  await recursivelyRemoveIgnored('', dir, filter);
}

/**
 * Recursively scan a directory for ignored files, and remove them.
 * 
 * @param {string} dir the directory to filter
 * @param {*} filter an instance of `ignore`
 */
async function recursivelyRemoveIgnored(dir, basedir, filter) {
  const dirPath = basedir + '/' + dir;
  const files = fs.readdirSync(dirPath)

  await asyncForEach(files, async (file) => {
    if (filter.ignores(dir + file)) {
      await rimraf(`${dirPath}${file}`);
    } else if (fs.statSync(dirPath + '/' + file).isDirectory()) {
      await recursivelyRemoveIgnored(dir ? dir + '/' + file : file, basedir, filter)
    }
  })
}

async function asyncForEach(array, callback) {
  for (let index = 0; index < array.length; index++) {
    await callback(array[index], index, array);
  }
}


/**
 * Zip the checkout folder.
 * 
 * @param {string} dir the checkout directory. Defaults to `/tmp/checkout`
 */
exports.zip = async (dir) => { }