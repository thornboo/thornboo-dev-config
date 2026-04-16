#!/usr/bin/env perl

use strict;
use warnings;

my ($source_path, $destination_path, $output_path) = @ARGV;

die "source, destination, and output paths are required\n"
  unless defined $source_path && defined $destination_path && defined $output_path;

sub slurp_file {
  my ($path) = @_;

  open my $handle, '<:raw', $path or die "Cannot open $path: $!\n";
  local $/;
  my $content = <$handle>;
  close $handle;

  return $content;
}

sub write_file {
  my ($path, $content) = @_;

  open my $handle, '>:raw', $path or die "Cannot write $path: $!\n";
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

sub merge_query_placeholders {
  my ($source_value, $destination_value) = @_;
  my %destination_params = ();
  my $merged_value = $source_value;

  while ($destination_value =~ /[?&]([^=&?#"'\s]+)=([^&#"'\s]*)/g) {
    $destination_params{$1} = $2;
  }

  $merged_value =~ s{
    ([?&])([^=&?#"'\s]+)=<REDACTED>
  }{
    my ($separator, $name) = ($1, $2);

    if (exists $destination_params{$name} && $destination_params{$name} ne '<REDACTED>') {
      $separator . $name . '=' . $destination_params{$name};
    } else {
      $&;
    }
  }gex;

  return $merged_value;
}

my $source_content = slurp_file($source_path);
my $destination_content = slurp_file($destination_path);
my %all_values = ();

while ($destination_content =~ /(["'])([^"']+)\1\s*:\s*(["'])(.*?)\3/gsi) {
  $all_values{normalize_key($2)} = $4;
}

while ($destination_content =~ /(^\s*(?:export\s+)?([A-Za-z0-9_.-]+)\s*[:=]\s*)(["'])(.*?)\3/gm) {
  $all_values{normalize_key($2)} = $4;
}

while ($destination_content =~ /(^\s*(?:export\s+)?([A-Za-z0-9_.-]+)\s*[:=]\s*)([^#;\r\n]+)/gm) {
  $all_values{normalize_key($2)} = $3;
}

$source_content =~ s{
  ((["'])([^"']+)\2\s*:\s*)(["'])(.*?)\4
}{
  my ($prefix, $key, $quote, $value) = ($1, $3, $4, $5);
  my $normalized_key = normalize_key($key);
  my $destination_value = $all_values{$normalized_key};

  if (is_sensitive_key($key) && defined $destination_value && $destination_value ne '<REDACTED>') {
    $prefix . $quote . $destination_value . $quote;
  } elsif ($value =~ /<REDACTED>/ && defined $destination_value) {
    $prefix . $quote . merge_query_placeholders($value, $destination_value) . $quote;
  } else {
    $&;
  }
}gsex;

$source_content =~ s{
  (^\s*(?:export\s+)?([A-Za-z0-9_.-]+)\s*[:=]\s*)(["'])(.*?)\3(\s*(?:[#;].*)?)$
}{
  my ($prefix, $key, $quote, $value, $suffix) = ($1, $2, $3, $4, $5 // '');
  my $normalized_key = normalize_key($key);
  my $destination_value = $all_values{$normalized_key};

  if (is_sensitive_key($key) && defined $destination_value && $destination_value ne '<REDACTED>') {
    $prefix . $quote . $destination_value . $quote . $suffix;
  } elsif ($value =~ /<REDACTED>/ && defined $destination_value) {
    $prefix . $quote . merge_query_placeholders($value, $destination_value) . $quote . $suffix;
  } else {
    $&;
  }
}gimsex;

$source_content =~ s{
  (^\s*(?:export\s+)?([A-Za-z0-9_.-]+)\s*[:=]\s*)([^#;\r\n]+)(\s*(?:[#;].*)?)$
}{
  my ($prefix, $key, $value, $suffix) = ($1, $2, $3, $4 // '');
  my $normalized_key = normalize_key($key);
  my $destination_value = $all_values{$normalized_key};

  if (is_sensitive_key($key) && defined $destination_value && $destination_value !~ /<REDACTED>/) {
    $prefix . $destination_value . $suffix;
  } elsif ($value =~ /<REDACTED>/ && defined $destination_value) {
    $prefix . merge_query_placeholders($value, $destination_value) . $suffix;
  } else {
    $&;
  }
}gimsex;

write_file($output_path, $source_content);
