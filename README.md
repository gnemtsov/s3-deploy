# s3-deploy
Bash script for simple AWS S3 deployments.
It finds all static files links in HTML. Then it checks files modification timestamps and updates `?ver=v13434` part of the links. This is needed to prevent unnecessary caching and force reload of all modified files. After that, it bundles js-scripts and uploads files to the bucket while setting cache control headers max-age=0 for all files except HTML. This is needed to force a refresh of the AWS CloudFront cache.

To use this script you need a config file (deploy.config) in the root folder of you project:
```
bucket=mybucket
exclude=.git/*,some_dir/*,secret_file    # files and directories to exclude from uploading
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
