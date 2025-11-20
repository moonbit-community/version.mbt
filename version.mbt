// Copyright (c) HashiCorp, Inc.
// Copyright (c) 2025 International Digital Economy Academy
// SPDX-License-Identifier: MPL-2.0

///|
// Error type for version parsing  
pub suberror VersionError String

///|
impl Show for VersionError with output(self, logger) {
  logger.write_string("VersionError: ")
  match self {
    VersionError(msg) => logger.write_string(msg)
  }
}

///|
/// Version represents a single version.
pub struct Version {
  metadata : String
  pre : String
  segments : Array[Int64]
  si : Int
  original : String
} derive(Eq, Show)

///|
/// Create a new Version from a string
pub fn Version::new(v : String) -> Version raise VersionError {
  new_version(v)
}

///|
/// Create a new Version that adheres strictly to SemVer specs
pub fn Version::new_semver(v : String) -> Version raise VersionError {
  new_version_semver(v)
}

///|
/// Helper function to compare strings character by character for proper lexicographic ordering
/// Returns -1 if a < b, 0 if a == b, 1 if a > b
fn string_compare(a : String, b : String) -> Int {
  if a == b {
    return 0
  }
  let len_a = a.length()
  let len_b = b.length()
  let min_len = if len_a < len_b { len_a } else { len_b }
  for i = 0; i < min_len; i = i + 1 {
    let char_a = a[i]
    let char_b = b[i]
    if char_a < char_b {
      return -1
    } else if char_a > char_b {
      return 1
    }
  }

  // If all compared characters are equal, the shorter string comes first
  if len_a < len_b {
    -1
  } else if len_a > len_b {
    1
  } else {
    0
  }
}

///|
/// Helper function to check if a character code is a digit (optimized)
fn is_digit_code(code : Int) -> Bool {
  // Ultra-optimized digit checking using bit operations
  // ASCII '0' = 48 (0x30), '9' = 57 (0x39)
  // For digit range check: subtract 48 and check if result is <= 9
  // This is faster than two comparisons
  let offset = code - 48
  offset >= 0 && offset <= 9
}

///|
/// Helper function to convert a digit character code to Int64
fn char_code_to_digit(code : Int) -> Int64? {
  if is_digit_code(code) {
    Some((code - '0'.to_int()).to_int64())
  } else {
    None
  }
}

///|
/// Helper function to check if a string contains only digits
fn is_all_digits(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  for i = 0; i < s.length(); i = i + 1 {
    if !is_digit_code(s[i]) {
      return false
    }
  }
  true
}

///|
/// Fast path check for simple versions like "1.2.3" (no prerelease, metadata, or 'v' prefix)
fn try_fast_parse_simple_version(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }

  // Must start with digit
  if !is_digit_code(s[0]) {
    return false
  }

  // Check for presence of characters that indicate complex version
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    // Allow only digits and dots for simple versions
    if !is_digit_code(c) && c != '.'.to_int() {
      return false
    }
  }

  // Must not start or end with dot, and no consecutive dots
  if s[0] == '.'.to_int() || s[s.length() - 1] == '.'.to_int() {
    return false
  }

  // Check for consecutive dots
  for i = 0; i < s.length() - 1; i = i + 1 {
    if s[i] == '.'.to_int() && s[i + 1] == '.'.to_int() {
      return false
    }
  }
  true
}

///|
/// Parse simple numeric version (fast path) 
fn parse_simple_numeric_version(
  s : String,
  original : String,
) -> Version raise VersionError {
  let segments_str = s.split(".")
  let segments : Array[Int64] = []
  let mut actual_segment_count = 0
  for str in segments_str {
    let str_string = str.to_string()
    if str_string.length() == 0 {
      raise VersionError(
        "malformed version '\{original}': empty segment found in version components",
      )
    }
    match try_parse_int(str_string) {
      Some(val) => segments.push(val)
      None => raise VersionError("malformed version: \{original}")
    }
    actual_segment_count = actual_segment_count + 1
  }

  // Pad to at least 3 segments  
  while segments.length() < 3 {
    segments.push(0L)
  }
  Version::{
    metadata: "",
    pre: "",
    segments,
    si: actual_segment_count,
    original,
  }
}

///|
/// Helper function to parse a string to Int64, returns None if invalid
/// Optimized version using character operations
fn try_parse_int(s : String) -> Int64? {
  if s.length() == 0 {
    return None
  }

  // Quick check for all digits
  if !is_all_digits(s) {
    return None
  }
  let mut parsed_val = 0L
  for i = 0; i < s.length(); i = i + 1 {
    match char_code_to_digit(s[i]) {
      Some(digit) => parsed_val = parsed_val * 10L + digit
      None => return None // Should not happen due to is_all_digits check
    }
  }
  Some(parsed_val)
}

///|
fn new_version_semver(v : String) -> Version raise VersionError {
  let trimmed = v.trim_space()

  // Check for empty version
  if trimmed.length() == 0 {
    raise VersionError(
      "malformed version: cannot parse empty string as version",
    )
  }

  // Remove optional 'v' prefix
  let without_v = match trimmed.strip_prefix("v") {
    Some(stripped) => stripped.to_string()
    None => trimmed.to_string()
  }

  // Basic validation: version should start with a digit
  if without_v.length() == 0 || !is_digit_code(without_v[0]) {
    raise VersionError(
      "malformed version '\{v}': version must start with a digit after optional 'v' prefix",
    )
  }

  // Stricter SemVer validation: reject patterns like "1.7rc2", "1.0-"
  // Split on + for metadata (only first occurrence)
  let metadata_parts = without_v.split("+")
  let mut version_part = ""
  let mut metadata = ""
  let mut part_count = 0
  for part in metadata_parts {
    if part_count == 0 {
      version_part = part.to_string()
    } else if metadata.length() > 0 {
      metadata = metadata + "+" + part.to_string()
    } else {
      metadata = part.to_string()
    }
    part_count = part_count + 1
  }

  // Split on - for prerelease (only first occurrence)
  let prerelease_parts = version_part.split("-")
  let mut core_part = ""
  let mut pre = ""
  part_count = 0
  for part in prerelease_parts {
    if part_count == 0 {
      core_part = part.to_string()
    } else if pre.length() > 0 {
      pre = pre + "-" + part.to_string()
    } else {
      pre = part.to_string()
    }
    part_count = part_count + 1
  }

  // Validate core part is not empty
  if core_part.length() == 0 {
    raise VersionError("malformed version: \{v}")
  }

  // SemVer stricter validation: reject if prerelease is empty but dash is present
  if version_part.strip_suffix("-") is Some(_) && pre.length() == 0 {
    raise VersionError("malformed version: \{v}")
  }

  // Check for invalid characters in prerelease section
  if pre.length() > 0 {
    // Must be separated properly from main version
    if !version_part.contains("-") {
      raise VersionError("malformed version: \{v}")
    }
  }

  // Parse version segments - each must be a valid number
  let segments_str = core_part.split(".")
  let segments : Array[Int64] = []
  let mut actual_segment_count = 0
  for str in segments_str {
    let str_string = str.to_string()
    // Check for empty segments
    if str_string.length() == 0 {
      raise VersionError("malformed version: \{v}")
    }
    // Validate that segment contains only digits (no alpha characters)
    if !is_all_digits(str_string) {
      raise VersionError("malformed version: \{v}")
    }
    match try_parse_int(str_string) {
      Some(val) => segments.push(val)
      None => raise VersionError("malformed version: \{v}")
    }
    actual_segment_count = actual_segment_count + 1
  }

  // For SemVer, check if there are invalid characters attached to main version
  // This catches cases like "1.7rc2" where "rc2" is not properly separated with a dash
  if pre.length() == 0 {
    // Check if the original version (without v prefix) contains letters mixed with numbers
    // without proper dash separation
    let mut has_letter_after_digit = false
    let mut found_digit = false
    for i = 0; i < core_part.length(); i = i + 1 {
      let c = core_part[i]
      if is_digit_code(c) {
        found_digit = true
      } else if c != '.'.to_int() {
        if found_digit {
          has_letter_after_digit = true
          break
        }
      }
    }
    if has_letter_after_digit {
      raise VersionError("malformed version: \{v}")
    }
  }

  // Pad to at least 3 segments (MAJOR.MINOR.PATCH)
  while segments.length() < 3 {
    segments.push(0L)
  }
  Version::{ metadata, pre, segments, si: actual_segment_count, original: v }
}

///|
fn new_version(v : String) -> Version raise VersionError {
  let trimmed = v.trim_space()

  // Check for empty version
  if trimmed.length() == 0 {
    raise VersionError("malformed version: empty string")
  }

  // Fast path for simple numeric versions like "1.2.3" (most common case)
  let trimmed_str = trimmed.to_string()
  if try_fast_parse_simple_version(trimmed_str) {
    return parse_simple_numeric_version(trimmed_str, v)
  }

  // Remove optional 'v' prefix
  let without_v = match trimmed.strip_prefix("v") {
    Some(stripped) => stripped.to_string()
    None => trimmed.to_string()
  }

  // Basic validation: version should start with a digit
  if without_v.length() == 0 || !is_digit_code(without_v[0]) {
    raise VersionError("malformed version: \{v}")
  }

  // More permissive parsing like Go version
  // Parse version similar to Go's regex: `v?([0-9]+(\.[0-9]+)*?)(-([0-9]+[0-9A-Za-z\-~]*(\.[0-9A-Za-z\-~]+)*)|(-?([A-Za-z\-~]+[0-9A-Za-z\-~]*(\.[0-9A-Za-z\-~]+)*)))?(\+([0-9A-Za-z\-~]+(\.[0-9A-Za-z\-~]+)*))?`

  // Split on + for metadata (only first occurrence)
  let metadata_parts = without_v.split("+")
  let mut version_part = ""
  let mut metadata = ""
  let mut part_count = 0
  for part in metadata_parts {
    if part_count == 0 {
      version_part = part.to_string()
      // Join remaining parts back (in case + appears in metadata)
    } else if metadata.length() > 0 {
      metadata = metadata + "+" + part.to_string()
    } else {
      metadata = part.to_string()
    }
    part_count = part_count + 1
  }

  // Now parse the version_part for numeric segments and prerelease
  let mut core_part = ""
  let mut pre = ""

  // Find where the numeric part ends and prerelease begins
  let mut i = 0
  let mut found_non_digit_non_dot = false
  while i < version_part.length() && !found_non_digit_non_dot {
    let char_code = version_part[i]
    let is_dot = char_code == '.'.to_int()
    if is_digit_code(char_code) || is_dot {
      i = i + 1
    } else if char_code == '-'.to_int() {
      // Found explicit prerelease separator
      core_part = version_part[0:i].to_string() catch {
        _ => raise VersionError("malformed version: {v}")
      }
      pre = version_part[i + 1:].to_string() catch {
        _ => raise VersionError("malformed version: {v}")
      }
      found_non_digit_non_dot = true
    } else {
      // Found alpha character without dash - this is an implicit prerelease like "1.2.3alpha1"
      core_part = version_part[0:i].to_string() catch {
        _ => raise VersionError("malformed version: {v}")
      }
      pre = version_part[i:].to_string() catch {
        _ => raise VersionError("malformed version: {v}")
      }
      found_non_digit_non_dot = true
    }
  }
  if !found_non_digit_non_dot {
    // No prerelease found
    core_part = version_part.to_string()
    pre = ""
  }

  // Validate core part is not empty
  if core_part.length() == 0 {
    raise VersionError("malformed version: \{v}")
  }

  // Parse version segments - each must be a valid number
  let segments_str = core_part.split(".")
  let segments : Array[Int64] = []
  let mut actual_segment_count = 0
  for str in segments_str {
    let str_string = str.to_string()
    // Check for empty segments
    if str_string.length() == 0 {
      raise VersionError("malformed version: \{v}")
    }
    // Validate that segment contains only digits (no alpha characters)
    if !is_all_digits(str_string) {
      raise VersionError("malformed version: \{v}")
    }
    match try_parse_int(str_string) {
      Some(val) => segments.push(val)
      None => raise VersionError("malformed version: \{v}")
    }
    actual_segment_count = actual_segment_count + 1
  }

  // Pad to at least 3 segments (MAJOR.MINOR.PATCH)
  while segments.length() < 3 {
    segments.push(0L)
  }
  Version::{ metadata, pre, segments, si: actual_segment_count, original: v }
}

///|
/// Must is a helper that wraps a call to a function returning (Version, error)
/// and panics if error is non-nil.
pub fn must(v : Result[Version, VersionError]) -> Version {
  match v {
    Ok(version) => version
    Err(e) => abort("Version parse error: \{e}")
  }
}

///|
/// Must wrapper for Version::new
pub fn Version::must(v : String) -> Version {
  Version::new(v) catch {
    e => abort("Version parse error: \{e}")
  }
}

///|
/// Must wrapper for Version::new_semver
pub fn Version::must_semver(v : String) -> Version {
  Version::new_semver(v) catch {
    e => abort("Version parse error: \{e}")
  }
}

///|
/// Compare compares this version to another version. This
/// returns -1, 0, or 1 if this version is smaller, equal,
/// or larger than the other version, respectively.
pub fn Version::compare(self : Version, other : Version) -> Int {
  // Quick equality check
  if self.to_string() == other.to_string() {
    return 0
  }

  // If the segments are the same, we must compare on prerelease info
  if self.equal_segments(other) {
    let pre_self = self.prerelease()
    let pre_other = other.prerelease()
    if pre_self == "" && pre_other == "" {
      return 0
    }
    if pre_self == "" {
      return 1
    }
    if pre_other == "" {
      return -1
    }
    return compare_prereleases(pre_self, pre_other)
  }
  let segments_self = self.segments64()
  let segments_other = other.segments64()
  let len_self = segments_self.length()
  let len_other = segments_other.length()
  let hs = if len_self < len_other { len_other } else { len_self }

  // Compare the segments
  for i = 0; i < hs; i = i + 1 {
    if i > len_self - 1 {
      // Self had lower specificity
      if !all_zero_from_index(segments_other, i) {
        return -1
      }
      break
    } else if i > len_other - 1 {
      // Other had lower specificity  
      if !all_zero_from_index(segments_self, i) {
        return 1
      }
      break
    }
    let lhs = segments_self[i]
    let rhs = segments_other[i]
    if lhs == rhs {
      continue
    } else if lhs < rhs {
      return -1
    }
    return 1
  }
  0
}

///|
pub fn Version::equal_segments(self : Version, other : Version) -> Bool {
  let segments_self = self.segments64()
  let segments_other = other.segments64()
  if segments_self.length() != segments_other.length() {
    return false
  }
  for i = 0; i < segments_self.length(); i = i + 1 {
    if segments_self[i] != segments_other[i] {
      return false
    }
  }
  true
}

///|
fn all_zero_from_index(segs : Array[Int64], start_index : Int) -> Bool {
  for i = start_index; i < segs.length(); i = i + 1 {
    if segs[i] != 0L {
      return false
    }
  }
  true
}

///|
fn compare_part(pre_self : String, pre_other : String) -> Int {
  if pre_self == pre_other {
    return 0
  }
  let mut self_numeric = false
  let mut other_numeric = false
  let mut self_int = 0L
  let mut other_int = 0L
  // Parse pre_self as integer using try_parse_int helper
  match try_parse_int(pre_self) {
    Some(val) => {
      self_numeric = true
      self_int = val
    }
    None => self_numeric = false
  }

  // Parse pre_other as integer using try_parse_int helper
  match try_parse_int(pre_other) {
    Some(val) => {
      other_numeric = true
      other_int = val
    }
    None => other_numeric = false
  }

  // If a part is empty, we use the other to decide
  if pre_self == "" {
    return if other_numeric { -1 } else { 1 }
  }
  if pre_other == "" {
    return if self_numeric { 1 } else { -1 }
  }
  if self_numeric && !other_numeric {
    return -1
  } else if !self_numeric && other_numeric {
    return 1
  } else if !self_numeric && !other_numeric {
    return string_compare(pre_self, pre_other)
  } else if self_int > other_int {
    return 1
  } else if self_int < other_int {
    return -1
  } else {
    return 0
  }
}

///|
fn compare_prereleases(v : String, other : String) -> Int {
  // The same pre release!
  if v == other {
    return 0
  }

  // Split both pre releases to analyze their parts and convert directly to arrays
  let self_parts : Array[String] = []
  for part in v.split(".") {
    self_parts.push(part.to_string())
  }
  let other_parts : Array[String] = []
  for part in other.split(".") {
    other_parts.push(part.to_string())
  }
  let self_pre_release_len = self_parts.length()
  let other_pre_release_len = other_parts.length()
  let biggest_len = if self_pre_release_len > other_pre_release_len {
    self_pre_release_len
  } else {
    other_pre_release_len
  }

  // Loop for parts to find the first difference
  for i = 0; i < biggest_len; i = i + 1 {
    let part_self_pre = if i < self_pre_release_len {
      self_parts[i]
    } else {
      ""
    }
    let part_other_pre = if i < other_pre_release_len {
      other_parts[i]
    } else {
      ""
    }
    let compare_result = compare_part(part_self_pre, part_other_pre)
    // If parts are equal, continue the loop
    if compare_result != 0 {
      return compare_result
    }
  }
  0
}

///|
/// Core returns a new version constructed from only the MAJOR.MINOR.PATCH
/// segments of the version, without prerelease or metadata.
pub fn Version::core(self : Version) -> Version raise VersionError {
  let segments = self.segments64()
  let segments_only = "\{segments[0]}.\{segments[1]}.\{segments[2]}"
  Version::new(segments_only)
}

///|
/// Equal tests if two versions are equal.
pub fn Version::equal(self : Version, other : Version) -> Bool {
  self.compare(other) == 0
}

///|
/// GreaterThan tests if this version is greater than another version.
pub fn Version::greater_than(self : Version, other : Version) -> Bool {
  self.compare(other) > 0
}

///|
/// GreaterThanOrEqual tests if this version is greater than or equal to another version.
pub fn Version::greater_than_or_equal(self : Version, other : Version) -> Bool {
  self.compare(other) >= 0
}

///|
/// LessThan tests if this version is less than another version.
pub fn Version::less_than(self : Version, other : Version) -> Bool {
  self.compare(other) < 0
}

///|
/// LessThanOrEqual tests if this version is less than or equal to another version.  
pub fn Version::less_than_or_equal(self : Version, other : Version) -> Bool {
  self.compare(other) <= 0
}

///|
/// Metadata returns any metadata that was part of the version string.
/// Metadata is anything that comes after the "+" in the version.
pub fn Version::metadata(self : Version) -> String {
  self.metadata
}

///|
/// Prerelease returns any prerelease data that is part of the version.
/// Prerelease information is anything that comes after the "-" in the version.
pub fn Version::prerelease(self : Version) -> String {
  self.pre
}

///|
/// Segments returns the numeric segments of the version as a slice of ints.
pub fn Version::segments(self : Version) -> Array[Int] {
  let segment_slice : Array[Int] = []
  for v in self.segments {
    segment_slice.push(v.to_int())
  }
  segment_slice
}

///|
/// Segments64 returns the numeric segments of the version as a slice of int64s.
pub fn Version::segments64(self : Version) -> Array[Int64] {
  let result : Array[Int64] = []
  for seg in self.segments {
    result.push(seg)
  }
  result
}

///|
/// String returns the full version string including pre-release and metadata information.
/// Optimized version using array-based concatenation for better performance
pub fn Version::to_string(self : Version) -> String {
  // Use array-based approach for more efficient string building
  let parts : Array[String] = []

  // Add version segments
  for i = 0; i < self.segments.length(); i = i + 1 {
    if i > 0 {
      parts.push(".")
    }
    parts.push(self.segments[i].to_string())
  }

  // Add prerelease if present
  if self.pre != "" {
    parts.push("-")
    parts.push(self.pre)
  }

  // Add metadata if present
  if self.metadata != "" {
    parts.push("+")
    parts.push(self.metadata)
  }

  // Join all parts efficiently
  let mut result = ""
  for part in parts {
    result = result + part
  }
  result
}

///|
/// Original returns the original parsed version as-is
pub fn Version::original(self : Version) -> String {
  self.original
}

///|
/// Marshal version to JSON string (equivalent to MarshalText)
pub fn Version::to_json(self : Version) -> String {
  self.to_string()
}

///|
/// Unmarshal version from JSON string (equivalent to UnmarshalText)
pub fn Version::from_json(json_str : String) -> Version raise VersionError {
  // Remove quotes if present (JSON strings are quoted)
  let unquoted = if json_str.strip_prefix("\"") is Some(without_prefix) &&
    without_prefix.strip_suffix("\"") is Some(without_suffix) {
    without_suffix.to_string()
  } else {
    json_str
  }
  Version::new(unquoted)
}

///|
/// Convert version to a database-compatible string (equivalent to Value)
pub fn Version::to_db_string(self : Version) -> String {
  self.to_string()
}

///|
/// Create version from a database-compatible value (equivalent to Scan)
pub fn Version::from_db_string(db_str : String) -> Version raise VersionError {
  Version::new(db_str)
}

///|
/// Check if version is stable (no prerelease)
pub fn Version::is_stable(self : Version) -> Bool {
  self.pre == ""
}

///|
/// Check if version is prerelease
pub fn Version::is_prerelease(self : Version) -> Bool {
  self.pre != ""
}

///|
/// Get major version number (first segment)
pub fn Version::major(self : Version) -> Int64 {
  if self.segments.length() > 0 {
    self.segments[0]
  } else {
    0L
  }
}

///|
/// Get minor version number (second segment)
pub fn Version::minor(self : Version) -> Int64 {
  if self.segments.length() > 1 {
    self.segments[1]
  } else {
    0L
  }
}

///|
/// Get patch version number (third segment)  
pub fn Version::patch(self : Version) -> Int64 {
  if self.segments.length() > 2 {
    self.segments[2]
  } else {
    0L
  }
}

///|
/// Create a new version with incremented major version
pub fn Version::increment_major(self : Version) -> Version raise VersionError {
  let new_version = "\{self.major() + 1L}.0.0"
  Version::new(new_version)
}

///|
/// Create a new version with incremented minor version
pub fn Version::increment_minor(self : Version) -> Version raise VersionError {
  let new_version = "\{self.major()}.\{self.minor() + 1L}.0"
  Version::new(new_version)
}

///|
/// Create a new version with incremented patch version
pub fn Version::increment_patch(self : Version) -> Version raise VersionError {
  let new_version = "\{self.major()}.\{self.minor()}.\{self.patch() + 1L}"
  Version::new(new_version)
}
