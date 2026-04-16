#!/usr/bin/env perl

use strict;
use warnings;

my $path = shift @ARGV or die "path is required\n";

sub slurp_file {
  my ($file_path) = @_;

  open my $handle, '<:raw', $file_path or die "Cannot open $file_path: $!\n";
  local $/;
  my $content = <$handle>;
  close $handle;

  return $content;
}

sub write_file {
  my ($file_path, $content) = @_;

  open my $handle, '>:raw', $file_path or die "Cannot write $file_path: $!\n";
  print {$handle} $content;
  close $handle;
}

sub normalize_key {
  my ($key) = @_;

  my $normalized = lc $key;
  $normalized =~ s/[^a-z0-9]+//g;

  return $normalized;
}

sub is_meta_secret_reference_key {
  my ($key) = @_;
  my $normalized = normalize_key($key);

  return 1 if $normalized =~ /envvar$/;
  return 1 if $normalized =~ /envname$/;

  return 0;
}

sub is_sensitive_key {
  my ($key) = @_;
  my $normalized = normalize_key($key);
  my @suffixes = qw(
    apikey
    accesstoken
    refreshtoken
    authtoken
    authorization
    clientsecret
    bearertoken
    sessiontoken
    idtoken
    token
    secret
    password
    passwd
  );

  return 0 if is_meta_secret_reference_key($key);

  for my $suffix (@suffixes) {
    return 1 if $normalized eq $suffix;
    return 1 if $normalized =~ /$suffix$/;
  }

  return 0;
}

sub redact_query_params {
  my ($value) = @_;

  $value =~ s{
    ([?&][^=&?#"'\s]*?(?:api(?:[_-]?|)key|access(?:[_-]?|)token|refresh(?:[_-]?|)token|auth(?:[_-]?|)token|authorization|client(?:[_-]?|)secret|bearer(?:[_-]?|)token|session(?:[_-]?|)token|id(?:[_-]?|)token|token|secret|password|passwd)[^=&?#"'\s]*?=)
    ([^&#"'\s]+)
  }{$1 . '<REDACTED>'}gixe;

  return $value;
}

sub redact_secret_literals {
  my ($value) = @_;

  $value =~ s{sk-[A-Za-z0-9_-]{12,}|github_pat_[A-Za-z0-9_]+|AIza[0-9A-Za-z_-]+}{<REDACTED>}g;

  return $value;
}

sub redact_env_assignments_in_line {
  my ($line) = @_;
  my $redacted_line = $line;

  $redacted_line =~ s{
    (\b[A-Za-z_][A-Za-z0-9_]*(?:API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|AUTH_TOKEN|AUTHORIZATION|TOKEN|SECRET|PASSWORD)[A-Za-z0-9_]*=)
    ("[^"]*"|'[^']*'|[^"'\s)]+)
  }{
    my ($prefix, $value) = ($1, $2);
    my $quote = '';

    if ($value =~ /^(["']).*\1$/) {
      $quote = substr($value, 0, 1);
      $prefix . $quote . '<REDACTED>' . $quote;
    } else {
      $prefix . '<REDACTED>';
    }
  }gex;

  return redact_secret_literals(redact_query_params($redacted_line));
}

sub redact_line {
  my ($line) = @_;

  $line =~ s{
    ((["'])([^"']+)\2\s*:\s*)(["'])(.*?)\4
  }{
    my ($prefix, $key, $quote, $value) = ($1, $3, $4, $5);

    if (is_sensitive_key($key)) {
      $prefix . $quote . '<REDACTED>' . $quote;
    } else {
      $prefix . $quote . redact_secret_literals(redact_query_params($value)) . $quote;
    }
  }gex;

  $line =~ s{
    (^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_.-]*)\s*[:=]\s*)(["'])(.*?)\3(\s*(?:[#;].*)?)$
  }{
    my ($prefix, $key, $quote, $value, $suffix) = ($1, $2, $3, $4, $5 // '');

    if (is_sensitive_key($key)) {
      $prefix . $quote . '<REDACTED>' . $quote . $suffix;
    } else {
      $prefix . $quote . redact_secret_literals(redact_query_params($value)) . $quote . $suffix;
    }
  }gex;

  $line =~ s{
    (^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_.-]*)\s*[:=]\s*)([^#;\r\n]+)(\s*(?:[#;].*)?)$
  }{
    my ($prefix, $key, $value, $suffix) = ($1, $2, $3, $4 // '');

    if (is_sensitive_key($key)) {
      $prefix . '<REDACTED>' . $suffix;
    } else {
      $prefix . redact_secret_literals(redact_query_params($value)) . $suffix;
    }
  }gex;

  return redact_env_assignments_in_line($line);
}

my $content = slurp_file($path);
my $original = $content;
my @lines = split /(?<=\n)/, $content, -1;

$content = join '', map { redact_line($_) } @lines;

if ($content ne $original) {
  write_file($path, $content);
  print "changed\n";
  exit 0;
}

print "unchanged\n";
