# s3-deploy
Bash script for simple AWS S3 deployments.
It uploads files to the bucket, corrects timestamps of files included in HTML, bundles js scripts.

To use this script you need a config file (deploy.config) in the root folder of you project:
```
bucket=mybucket
exclude=.git/*,.service/*,secret_file    # files and directories to exclude from uploading
bundle=script1.js,script2.js,script3.js  # scripts listed here would be removed from HTML files and bundeled into a single file, 
                                         # which will be minified
                                         # A separate bundle is created for every HTML file
```

You also need to install babel-cli and babel-preset-minify from npm:
```
npm install --save-dev babel-cli
npm install --save-dev babel-preset-minify
```

If you want this script to correct file versions timestamps in HTML, you should include them with a ?v=<number>:
```
<link rel="apple-touch-icon" sizes="180x180" href="/apple.png?ver=v123">
```

You can use following options:
```
-v,--verbose   - for detailed output
-n,--no-upload - do not upload result into bucket
```
