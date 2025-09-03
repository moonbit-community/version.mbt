// Copyright (c) HashiCorp, Inc.
// Copyright (c) 2025 International Digital Economy Academy
// SPDX-License-Identifier: MPL-2.0

///|
test "new_version_basic" {
  let cases = [
    ("", true),
    ("1.2.3", false),
    ("1.0", false),
    ("1", false),
    ("1.2.beta", true),
    ("1.21.beta", true),
    ("foo", true),
    ("1.2-5", false),
    ("1.2-beta.5", false),
    ("1.2.0-x.Y.0+metadata", false),
    ("1.2.0-x.Y.0+metadata-width-hyphen", false),
    ("1.2.3-rc1-with-hyphen", false),
    ("1.2.3.4", false),
    ("v1.2.3", false),
    ("foo1.2.3", true),
    ("1.7rc2", false),
    ("v1.7rc2", false),
    ("1.0-", false),
  ]
  for case in cases {
    let (version, should_err) = case
    try {
      let _ = Version::new(version)
      if should_err {
        abort("expected error for version: \{version}")
      }
    } catch {
      _ => if !should_err { abort("unexpected error for version: \{version}") }
    }
  }
}

///|
test "new_semver_basic" {
  let cases = [
    ("", true),
    ("1.2.3", false),
    ("1.0", false),
    ("1", false),
    ("1.2.beta", true),
    ("1.21.beta", true),
    ("foo", true),
    ("1.2-5", false),
    ("1.2-beta.5", false),
    ("1.2.0-x.Y.0+metadata", false),
    ("1.2.0-x.Y.0+metadata-width-hyphen", false),
    ("1.2.3-rc1-with-hyphen", false),
    ("1.2.3.4", false),
    ("v1.2.3", false),
    ("foo1.2.3", true),
    ("1.7rc2", true), // Different from regular version
    ("v1.7rc2", true), // Different from regular version
    ("1.0-", true), // Different from regular version
  ]
  for case in cases {
    let (version, should_err) = case
    try {
      let _ = Version::new_semver(version)
      if should_err {
        abort("expected error for semver: \{version}")
      }
    } catch {
      _ => if !should_err { abort("unexpected error for semver: \{version}") }
    }
  }
}

///|
test "core_version" {
  let cases = [
    ("1.2.3", "1.2.3"),
    ("2.3.4-alpha1", "2.3.4"),
    ("3.4.5alpha1", "3.4.5"),
    ("1.2.3-2", "1.2.3"),
    ("4.5.6-beta1+meta", "4.5.6"),
    ("5.6.7.1.2.3", "5.6.7"),
  ]
  for case in cases {
    let (v1_str, v2_str) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.core() catch {
      _ => abort("Failed to get core of \{v1_str}")
    }
    let expected = v2
    if !actual.equal(expected) {
      abort("expected core of \{v1_str} to be \{v2_str}, got \{actual}")
    }
  }
}

///|
test "version_compare" {
  let cases = [
    ("1.2.3", "1.4.5", -1),
    ("1.2-beta", "1.2-beta", 0),
    ("1.2", "1.1.4", 1),
    ("1.2", "1.2-beta", 1),
    ("1.2+foo", "1.2+beta", 0),
    ("v1.2", "v1.2-beta", 1),
    ("v1.2+foo", "v1.2+beta", 0),
    ("v1.2.3.4", "v1.2.3.4", 0),
    ("v1.2.0.0", "v1.2", 0),
    ("v1.2.0.0.1", "v1.2", 1),
    ("v1.2", "v1.2.0.0", 0),
    ("v1.2", "v1.2.0.0.1", -1),
    ("v1.2.0.0", "v1.2.0.0.1", -1),
    ("v1.2.3.0", "v1.2.3.4", -1),
    ("1.7rc2", "1.7rc1", 1),
    ("1.7rc2", "1.7", -1),
    ("1.2.0", "1.2.0-X-1.2.0+metadata~dist", 1),
  ]
  for case in cases {
    let (v1_str, v2_str, expected) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.compare(v2)
    if actual != expected {
      abort("\{v1_str} <=> \{v2_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "compare_prerelease" {
  let cases = [
    ("1.2-beta.2", "1.2-beta.2", 0),
    ("1.2-beta.1", "1.2-beta.2", -1),
    ("1.2-beta.2", "1.2-beta.11", -1),
    ("3.2-alpha.1", "3.2-alpha", 1),
    ("1.2-beta.2", "1.2-beta.1", 1),
    ("1.2-beta.11", "1.2-beta.2", 1),
    ("1.2-beta", "1.2-beta.3", -1),
    ("1.2-alpha", "1.2-beta.3", -1),
    ("1.2-beta", "1.2-alpha.3", 1),
    ("3.0-alpha.3", "3.0-rc.1", -1),
    ("3.0-alpha3", "3.0-rc1", -1),
    ("3.0-alpha.1", "3.0-alpha.beta", -1),
    ("5.4-alpha", "5.4-alpha.beta", 1),
    ("v1.2-beta.2", "v1.2-beta.2", 0),
    ("v1.2-beta.1", "v1.2-beta.2", -1),
    ("v3.2-alpha.1", "v3.2-alpha", 1),
    ("v3.2-rc.1-1-g123", "v3.2-rc.2", 1),
  ]
  for case in cases {
    let (v1_str, v2_str, expected) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.compare(v2)
    if actual != expected {
      abort("\{v1_str} <=> \{v2_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "version_metadata" {
  let cases = [
    ("1.2.3", ""),
    ("1.2-beta", ""),
    ("1.2.0-x.Y.0", ""),
    ("1.2.0-x.Y.0+metadata", "metadata"),
    ("1.2.0-metadata-1.2.0+metadata~dist", "metadata~dist"),
  ]
  for case in cases {
    let (version_str, expected) = case
    let v = Version::new(version_str) catch {
      _ => abort("Failed to create version from \{version_str}")
    }
    let actual = v.metadata()
    if actual != expected {
      abort(
        "metadata for \{version_str}: expected '\{expected}', got '\{actual}'",
      )
    }
  }
}

///|
test "version_prerelease" {
  let cases = [
    ("1.2.3", ""),
    ("1.2-beta", "beta"),
    ("1.2.0-x.Y.0", "x.Y.0"),
    ("1.2.0-7.Y.0", "7.Y.0"),
    ("1.2.0-x.Y.0+metadata", "x.Y.0"),
    ("1.2.0-metadata-1.2.0+metadata~dist", "metadata-1.2.0"),
    ("17.03.0-ce", "ce"),
  ]
  for case in cases {
    let (version_str, expected) = case
    let v = Version::new(version_str) catch {
      _ => abort("Failed to create version from \{version_str}")
    }
    let actual = v.prerelease()
    if actual != expected {
      abort(
        "prerelease for \{version_str}: expected '\{expected}', got '\{actual}'",
      )
    }
  }
}

///|
test "version_segments" {
  let cases = [
    ("1.2.3", [1, 2, 3]),
    ("1.2-beta", [1, 2, 0]),
    ("1-x.Y.0", [1, 0, 0]),
    ("1.2.0-x.Y.0+metadata", [1, 2, 0]),
    ("1.2.0-metadata-1.2.0+metadata~dist", [1, 2, 0]),
    ("17.03.0-ce", [17, 3, 0]), // zero-padded fields
  ]
  for case in cases {
    let (version_str, expected) = case
    let v = Version::new(version_str) catch {
      _ => abort("Failed to create version from \{version_str}")
    }
    let actual = v.segments()
    if actual != expected {
      abort("segments for \{version_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "version_segments64" {
  let cases = [
    ("1.2.3", [1L, 2L, 3L]),
    ("1.2-beta", [1L, 2L, 0L]),
    ("1-x.Y.0", [1L, 0L, 0L]),
    ("1.2.0-x.Y.0+metadata", [1L, 2L, 0L]),
    ("1.4.9223372036854775807", [1L, 4L, 9223372036854775807L]),
  ]
  for case in cases {
    let (version_str, expected) = case
    let v = Version::new(version_str) catch {
      _ => abort("Failed to create version from \{version_str}")
    }
    let actual = v.segments64()
    if actual != expected {
      abort(
        "segments64 for \{version_str}: expected \{expected}, got \{actual}",
      )
    }
  }
}

///|
test "version_string" {
  let cases = [
    ("1.2.3", "1.2.3"),
    ("1.2-beta", "1.2.0-beta"),
    ("1.2.0-x.Y.0", "1.2.0-x.Y.0"),
    ("1.2.0-x.Y.0+metadata", "1.2.0-x.Y.0+metadata"),
    ("1.2.0-metadata-1.2.0+metadata~dist", "1.2.0-metadata-1.2.0+metadata~dist"),
    ("17.03.0-ce", "17.3.0-ce"), // zero-padded fields
  ]
  for case in cases {
    let (input, expected) = case
    let v = Version::new(input) catch {
      _ => abort("Failed to create version from \{input}")
    }
    let actual = v.to_string()
    if actual != expected {
      abort("string for \{input}: expected '\{expected}', got '\{actual}'")
    }
    let original = v.original()
    if original != input {
      abort("original for \{input}: expected '\{input}', got '\{original}'")
    }
  }
}

///|
test "version_equal" {
  let cases = [
    ("1.2.3", "1.4.5", false),
    ("1.2-beta", "1.2-beta", true),
    ("1.2", "1.1.4", false),
    ("1.2", "1.2-beta", false),
    ("1.2+foo", "1.2+beta", true),
    ("v1.2", "v1.2-beta", false),
    ("v1.2+foo", "v1.2+beta", true),
    ("v1.2.3.4", "v1.2.3.4", true),
    ("v1.2.0.0", "v1.2", true),
    ("v1.2.0.0.1", "v1.2", false),
    ("v1.2", "v1.2.0.0", true),
    ("v1.2", "v1.2.0.0.1", false),
    ("v1.2.0.0", "v1.2.0.0.1", false),
    ("v1.2.3.0", "v1.2.3.4", false),
    ("1.7rc2", "1.7rc1", false),
    ("1.7rc2", "1.7", false),
    ("1.2.0", "1.2.0-X-1.2.0+metadata~dist", false),
  ]
  for case in cases {
    let (v1_str, v2_str, expected) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.equal(v2)
    if actual != expected {
      abort("\{v1_str} == \{v2_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "version_greater_than" {
  let cases = [
    ("1.2.3", "1.4.5", false),
    ("1.2-beta", "1.2-beta", false),
    ("1.2", "1.1.4", true),
    ("1.2", "1.2-beta", true),
    ("1.2+foo", "1.2+beta", false),
    ("v1.2", "v1.2-beta", true),
    ("v1.2+foo", "v1.2+beta", false),
    ("v1.2.3.4", "v1.2.3.4", false),
    ("v1.2.0.0", "v1.2", false),
    ("v1.2.0.0.1", "v1.2", true),
    ("v1.2", "v1.2.0.0", false),
    ("v1.2", "v1.2.0.0.1", false),
    ("v1.2.0.0", "v1.2.0.0.1", false),
    ("v1.2.3.0", "v1.2.3.4", false),
    ("1.7rc2", "1.7rc1", true),
    ("1.7rc2", "1.7", false),
    ("1.2.0", "1.2.0-X-1.2.0+metadata~dist", true),
  ]
  for case in cases {
    let (v1_str, v2_str, expected) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.greater_than(v2)
    if actual != expected {
      abort("\{v1_str} > \{v2_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "version_less_than" {
  let cases = [
    ("1.2.3", "1.4.5", true),
    ("1.2-beta", "1.2-beta", false),
    ("1.2", "1.1.4", false),
    ("1.2", "1.2-beta", false),
    ("1.2+foo", "1.2+beta", false),
    ("v1.2", "v1.2-beta", false),
    ("v1.2+foo", "v1.2+beta", false),
    ("v1.2.3.4", "v1.2.3.4", false),
    ("v1.2.0.0", "v1.2", false),
    ("v1.2.0.0.1", "v1.2", false),
    ("v1.2", "v1.2.0.0", false),
    ("v1.2", "v1.2.0.0.1", true),
    ("v1.2.0.0", "v1.2.0.0.1", true),
    ("v1.2.3.0", "v1.2.3.4", true),
    ("1.7rc2", "1.7rc1", false),
    ("1.7rc2", "1.7", true),
    ("1.2.0", "1.2.0-X-1.2.0+metadata~dist", false),
  ]
  for case in cases {
    let (v1_str, v2_str, expected) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.less_than(v2)
    if actual != expected {
      abort("\{v1_str} < \{v2_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "version_greater_than_or_equal" {
  let cases = [
    ("1.2.3", "1.4.5", false),
    ("1.2-beta", "1.2-beta", true),
    ("1.2", "1.1.4", true),
    ("1.2", "1.2-beta", true),
    ("1.2+foo", "1.2+beta", true),
    ("v1.2", "v1.2-beta", true),
    ("v1.2+foo", "v1.2+beta", true),
    ("v1.2.3.4", "v1.2.3.4", true),
    ("v1.2.0.0", "v1.2", true),
    ("v1.2.0.0.1", "v1.2", true),
    ("v1.2", "v1.2.0.0", true),
    ("v1.2", "v1.2.0.0.1", false),
    ("v1.2.0.0", "v1.2.0.0.1", false),
    ("v1.2.3.0", "v1.2.3.4", false),
    ("1.7rc2", "1.7rc1", true),
    ("1.7rc2", "1.7", false),
    ("1.2.0", "1.2.0-X-1.2.0+metadata~dist", true),
  ]
  for case in cases {
    let (v1_str, v2_str, expected) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.greater_than_or_equal(v2)
    if actual != expected {
      abort("\{v1_str} >= \{v2_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "version_less_than_or_equal" {
  let cases = [
    ("1.2.3", "1.4.5", true),
    ("1.2-beta", "1.2-beta", true),
    ("1.2", "1.1.4", false),
    ("1.2", "1.2-beta", false),
    ("1.2+foo", "1.2+beta", true),
    ("v1.2", "v1.2-beta", false),
    ("v1.2+foo", "v1.2+beta", true),
    ("v1.2.3.4", "v1.2.3.4", true),
    ("v1.2.0.0", "v1.2", true),
    ("v1.2.0.0.1", "v1.2", false),
    ("v1.2", "v1.2.0.0", true),
    ("v1.2", "v1.2.0.0.1", true),
    ("v1.2.0.0", "v1.2.0.0.1", true),
    ("v1.2.3.0", "v1.2.3.4", true),
    ("1.7rc2", "1.7rc1", false),
    ("1.7rc2", "1.7", true),
    ("1.2.0", "1.2.0-X-1.2.0+metadata~dist", false),
  ]
  for case in cases {
    let (v1_str, v2_str, expected) = case
    let v1 = Version::new(v1_str) catch {
      _ => abort("Failed to create version from \{v1_str}")
    }
    let v2 = Version::new(v2_str) catch {
      _ => abort("Failed to create version from \{v2_str}")
    }
    let actual = v1.less_than_or_equal(v2)
    if actual != expected {
      abort("\{v1_str} <= \{v2_str}: expected \{expected}, got \{actual}")
    }
  }
}

///|
test "must_helpers" {
  // Test successful parsing
  let v1 = Version::must("1.2.3")
  if v1.to_string() != "1.2.3" {
    abort("Version::must failed for valid version")
  }
  let v2 = Version::must_semver("1.2.3")
  if v2.to_string() != "1.2.3" {
    abort("Version::must_semver failed for valid version")
  }

  // Test with Result type
  let result_ok : Result[Version, VersionError] = Ok(
    Version::new("1.2.3") catch {
      _ => abort("Failed to create version")
    },
  )
  let v3 = must(result_ok)
  if v3.to_string() != "1.2.3" {
    abort("must function failed for Ok result")
  }
}

///|
test "json_marshaling" {
  let cases = [
    "1.2.3", "1.2.0-x.Y.0+metadata", "1.2.0-x.Y.0+metadata-width-hyphen", "1.2.3-rc1-with-hyphen",
    "1.2.3.4", "1.2.0.4-x.Y.0+metadata", "1.2.0.4-x.Y.0+metadata-width-hyphen", "1.2.0-X-1.2.0+metadata~dist",
    "1.2.3.4-rc1-with-hyphen",
  ]
  for version_str in cases {
    let v = Version::new(version_str) catch {
      _ => abort("Failed to create version from \{version_str}")
    }

    // Test to_json
    let json_str = v.to_json()
    if json_str != version_str {
      abort("to_json failed for \{version_str}: got \{json_str}")
    }

    // Test from_json with quotes (simulating actual JSON)
    let quoted_json = "\"\{version_str}\""
    let v_from_json = Version::from_json(quoted_json) catch {
      _ => abort("Failed to parse JSON for \{version_str}")
    }
    if !v.equal(v_from_json) {
      abort("from_json failed for \{version_str}")
    }

    // Test from_json without quotes
    let v_from_json_unquoted = Version::from_json(version_str) catch {
      _ => abort("Failed to parse unquoted JSON for \{version_str}")
    }
    if !v.equal(v_from_json_unquoted) {
      abort("from_json without quotes failed for \{version_str}")
    }
  }
}

///|
test "database_conversion" {
  let cases = [
    "1.2.3", "1.2.0-x.Y.0+metadata", "1.2.3-rc1-with-hyphen", "1.2.3.4",
  ]
  for version_str in cases {
    let v = Version::new(version_str) catch {
      _ => abort("Failed to create version from \{version_str}")
    }

    // Test to_db_string
    let db_str = v.to_db_string()
    if db_str != v.to_string() {
      abort("to_db_string failed for \{version_str}")
    }

    // Test from_db_string
    let v_from_db = Version::from_db_string(db_str) catch {
      _ => abort("Failed to parse database string for \{version_str}")
    }
    if !v.equal(v_from_db) {
      abort("from_db_string failed for \{version_str}")
    }
  }
}

///|
test "large_number_edge_cases" {
  // Test maximum Int64 value (from Go tests)
  let large_version_str = "1.4.9223372036854775807"
  let v = Version::new(large_version_str) catch {
    _ => abort("Failed to parse large version number")
  }
  let segments = v.segments64()
  let expected = [1L, 4L, 9223372036854775807L]
  if segments != expected {
    abort(
      "Large number parsing failed. Expected: \{expected}, Got: \{segments}",
    )
  }

  // Test version comparison with large numbers
  let v1 = Version::new("1.4.9223372036854775806") catch {
    _ => abort("Failed to parse large version")
  }
  let v2 = Version::new("1.4.9223372036854775807") catch {
    _ => abort("Failed to parse large version")
  }
  if !v1.less_than(v2) {
    abort("Large number comparison failed")
  }

  // Test version string representation with large numbers
  let str_repr = v.to_string()
  if str_repr != "1.4.9223372036854775807" {
    abort("Large number string representation failed. Got: \{str_repr}")
  }
}

///|
test "version_parsing_edge_cases" {
  // Test edge cases for version parsing
  let edge_cases = [
    // Whitespace handling
    ("  1.2.3  ", false),
    (" v1.2.3 ", false),

    // Leading zeros (should be handled gracefully)
    ("1.02.3", false),
    ("01.2.3", false),

    // Many segments
    ("1.2.3.4.5.6.7.8", false),

    // Very short versions
    ("1", false),
    ("1.2", false),
  ]
  for case in edge_cases {
    let (version_str, should_err) = case
    try {
      let v = Version::new(version_str)
      if should_err {
        abort("Expected error for edge case: \{version_str}")
      }
      // Verify it can round-trip
      let _ = Version::new(v.to_string()) catch {
        _ => abort("Round-trip failed for edge case: \{version_str}")
      }

    } catch {
      _ =>
        if !should_err {
          abort("Unexpected error for edge case: \{version_str}")
        }
    }
  }
}

///|
test "utility_functions" {
  let v = Version::new("1.2.3-alpha") catch {
    _ => abort("Failed to parse version")
  }

  // Test stability checks
  if v.is_stable() {
    abort("Expected is_stable() to be false for prerelease version")
  }
  if !v.is_prerelease() {
    abort("Expected is_prerelease() to be true for prerelease version")
  }
  let stable_v = Version::new("1.2.3") catch {
    _ => abort("Failed to parse stable version")
  }
  if !stable_v.is_stable() {
    abort("Expected is_stable() to be true for stable version")
  }
  if stable_v.is_prerelease() {
    abort("Expected is_prerelease() to be false for stable version")
  }

  // Test major/minor/patch accessors
  if v.major() != 1L {
    abort("Expected major() to be 1")
  }
  if v.minor() != 2L {
    abort("Expected minor() to be 2")
  }
  if v.patch() != 3L {
    abort("Expected patch() to be 3")
  }

  // Test increment functions
  let v_major = v.increment_major() catch {
    _ => abort("Failed to increment major")
  }
  if v_major.to_string() != "2.0.0" {
    abort(
      "Expected increment_major() to produce '2.0.0', got '\{v_major.to_string()}'",
    )
  }
  let v_minor = v.increment_minor() catch {
    _ => abort("Failed to increment minor")
  }
  if v_minor.to_string() != "1.3.0" {
    abort(
      "Expected increment_minor() to produce '1.3.0', got '\{v_minor.to_string()}'",
    )
  }
  let v_patch = v.increment_patch() catch {
    _ => abort("Failed to increment patch")
  }
  if v_patch.to_string() != "1.2.4" {
    abort(
      "Expected increment_patch() to produce '1.2.4', got '\{v_patch.to_string()}'",
    )
  }

  // Test with short version
  let short_v = Version::new("1") catch {
    _ => abort("Failed to parse short version")
  }
  if short_v.major() != 1L {
    abort("Expected major() to be 1 for short version")
  }
  if short_v.minor() != 0L {
    abort("Expected minor() to be 0 for short version")
  }
  if short_v.patch() != 0L {
    abort("Expected patch() to be 0 for short version")
  }
}
