var gulp = require('gulp');
var concat = require('gulp-concat-multi');


gulp.task('default', function () {
    console.log('Start concatenation files');
    
    var targetFolder = '';
    var concatFiles = [ 'devscripts/PartialSetup SqlScript.sql',
                        'devscripts/PartialSetup uspExecScriptsByKeys.sql',
                        'devscripts/PartialSetup uspDropMe.sql',
                        'devscripts/PartialSetup uspRebuilTable.sql',
                        'devscripts/PartialSetup uspReset.sql',
                        'devscripts/PartialSetup vForeignKeyCols.sql'];
    var separator = { newLine: '\r\n \r\n' };

    //concat({ 'Setup.sql' : concatFiles}, separator).pipe(gulp.dest(targetFolder));
    
    console.log('Concatenation performed for:');
    /*
    for (i = 0; i<concatFiles.length; i++) {
        console.log(concatFiles[i]);
    }
    */
    
    console.log('End concatenation');
});

gulp.start('default');