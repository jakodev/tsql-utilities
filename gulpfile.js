var gulp = require('gulp');
var concat = require('gulp-concat-multi');

gulp.task('default', function() {
    console.log('<default not implemented>');
})

gulp.task('concat_dev_scripts', function() {
    console.log('Start concatenation files...');
  
    var sourceFolder = 'devsrc/';
    var targetFolder = '';
    var concatFiles = [ sourceFolder + 'Header.sql',
                        sourceFolder + 'SqlScript.sql',
                        sourceFolder + 'uspExecScriptsByKeys.sql',
                        sourceFolder + 'uspDropMe.sql',
                        sourceFolder + 'uspRebuilTable.sql',
                        sourceFolder + 'uspReset.sql',
                        sourceFolder + 'vForeignKeyCols.sql',
                        sourceFolder + 'Footer.sql'
                      ];
    var separator = { newLine: '\r\n \r\n' };
    
    concat({ 'Setup.sql' : concatFiles}, separator).pipe(gulp.dest(targetFolder));
    
    console.log('Concatenation performed for the following files:');
    for (i = 0; i<concatFiles.length; i++) {
        console.log(concatFiles[i]);
    }
    
    console.log('...End concatenation.');
});


gulp.start('concat_dev_scripts');