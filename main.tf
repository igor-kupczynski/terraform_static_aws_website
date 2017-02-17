# --- Inputs ---------------------------------------------------------------
variable region {
  description = "AWS region to use"
  default = "us-east-1"
}

variable domain {
  description = "Domain under which the website is served"
}

variable index_document {
  description = "Document to serve if the root of the domain is requested"
  default = "index.html"
}

variable error_404_document {
  description = "Document to serve if requested object doesn't exist in the bucket"
}

variable ssl_certificate_arn {
  default = ""
  description = "ARN of the certificate covering the domain plus subdomains under which the website is accessed, e.g. domain.com and *.domain.com"
}


# --- Outputs --------------------------------------------------------------
output "s3_url" {
  value = "${aws_s3_bucket.storage_bucket.website_endpoint}"
}

output "s3_www_url" {
  value = "${aws_s3_bucket.storage_bucket.www_redirect}"
}

output "cloudfront_url" {
  value = "${aws_cloudfront_distribution.cdn.domain_name}"
}


# --- Resource configuraiton -----------------------------------------------

# Bucket to store the static website
resource "aws_s3_bucket" "storage_bucket" {
  bucket = "${var.domain}"
  acl = "public-read"

  policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[{
	"Sid":"PublicReadGetObject",
        "Effect":"Allow",
	  "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::${var.domain}/*"
      ]
    }
  ]
}
EOF

  website {
    index_document = "${var.index_document}"
    error_document = "${var.error_404_document}"
  }
}

# Bucket to redirect www --> non-www
resource "aws_s3_bucket" "www_redirect" {
  bucket = "www-${var.domain}"
  acl = "public-read"

  policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[{
	"Sid":"PublicReadGetObject",
        "Effect":"Allow",
	  "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::www-${var.domain}/*"
      ]
    }
  ]
}
EOF

  website {
    redirect_all_requests_to = "http://${var.domain}"  // TODO: replace for https
  }
}


# Cloudfront in front of the bucket
resource "aws_cloudfront_distribution" "cdn" {
  count = "${var.ssl_certificate_arn != "" ? 1 : 0}"
  
  origin {
    domain_name = "${aws_s3_bucket.storage_bucket.bucket_domain_name}"
    origin_id   = "origin-${var.domain}"
  }

  enabled             = true

  default_root_object = "${var.index_document}"

  custom_error_response {
    error_code = "404"
    error_caching_min_ttl = "300"
    response_code = "404"
    response_page_path = "/${var.error_404_document}"
  }

  aliases = ["${var.domain}"]

  price_class = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-${var.domain}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 1200
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    acm_certificate_arn = "${var.ssl_certificate_arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

