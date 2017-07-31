const ghpages = require('gh-pages');
const path = require('path');
const filecopy = require('filecopy');

console.log(
`
------------------
Publishing...`
);
 
filecopy('crane.js', 'build/crane.js', {
  mkdirp: true
}).then(() => {
  console.log("- copied crane.js to build/")
  ghpages.publish('build', {
    branch: 'gh-pages',
    repo: 'git@github.com:headjump/ld39.git'
  }, function(err) {
    if(err) {
      console.log("ERROR: " + err);
    } else {
      console.log("DONE :)");
    }
    console.log("------------------");
  });
});