A module which creates AWS infrastucture for serving a static website

It creates:

    1. S3 bucket configured to serve the stored resources as a webpage
    2. Cloudfront distribution which fronts the bucket

DNS configuration and publishing the website are left for the user and
are not a scope of this module.

It is assumed that the aws credentials are provided via env variables.

User needs to create an SSL certificate in AWS certificate manager.
