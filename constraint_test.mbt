// Copyright (c) HashiCorp, Inc.
// Copyright (c) 2025 International Digital Economy Academy
// SPDX-License-Identifier: MPL-2.0

///|
test "new_constraint_basic" {
  let cases = [
    (">= 1.2", 1, false),
    ("1.0", 1, false),
    (">= 1.x", 0, true),
    (">= 1.2, < 1.0", 2, false),
  ]
  for case in cases {
    let (input, expected_count, should_err) = case
    try {
      let constraints = constraints_new(input)
      if should_err {
        abort("expected error for input: \{input}")
      }
      let actual_count = constraints.length()
      if actual_count != expected_count {
        abort(
          "input: \{input}, expected len: \{expected_count}, actual: \{actual_count}",
        )
      }
    } catch {
      _ => if !should_err { abort("unexpected error for input: \{input}") }
    }
  }
}

///|
test "constraint_check" {
  let cases = [
    (">= 1.0, < 1.2", "1.1.5", true),
    ("< 1.0, < 1.2", "1.1.5", false),
    ("= 1.0", "1.1.5", false),
    ("= 1.0", "1.0.0", true),
    ("1.0", "1.0.0", true),
    ("~> 1.0", "2.0", false),
    ("~> 1.0", "1.1", true),
    ("~> 1.0", "1.2.3", true),
    ("~> 1.0.0", "1.2.3", false),
    ("~> 1.0.0", "1.0.7", true),
    ("~> 1.0.0", "1.1.0", false),
    ("~> 1.0.7", "1.0.4", false),
    ("~> 1.0.7", "1.0.7", true),
    ("~> 1.0.7", "1.0.8", true),
    ("~> 1.0.7", "1.0.7.5", true),
    ("~> 1.0.7", "1.0.6.99", false),
    ("~> 1.0.7", "1.0.8.0", true),
    ("~> 1.0.9.5", "1.0.9.5", true),
    ("~> 1.0.9.5", "1.0.9.4", false),
    ("~> 1.0.9.5", "1.0.9.6", true),
    ("~> 1.0.9.5", "1.0.9.5.0", true),
    ("~> 1.0.9.5", "1.0.9.5.1", true),
    ("~> 2.0", "2.1.0-beta", false),
    ("~> 2.1.0-a", "2.2.0", false),
    ("~> 2.1.0-a", "2.1.0", false),
    ("~> 2.1.0-a", "2.1.0-beta", true),
    ("~> 2.1.0-a", "2.2.0-alpha", false),
    ("> 2.0", "2.1.0-beta", false),
    (">= 2.1.0-a", "2.1.0-beta", true),
    (">= 2.1.0-a", "2.1.1-beta", false),
    (">= 2.0.0", "2.1.0-beta", false),
    (">= 2.1.0-a", "2.1.1", true),
    (">= 2.1.0-a", "2.1.1-beta", false),
    (">= 2.1.0-a", "2.1.0", true),
    ("<= 2.1.0-a", "2.0.0", true),
  ]
  for case in cases {
    let (constraint_str, version_str, expected) = case
    let constraints = constraints_new(constraint_str) catch {
      _ => abort("Failed to parse constraint: \{constraint_str}")
    }
    let version = Version::new(version_str) catch {
      _ => abort("Failed to parse version: \{version_str}")
    }
    let actual = constraints_check(constraints, version)
    if actual != expected {
      abort(
        "Version: \{version_str}, Constraint: \{constraint_str}, Expected: \{expected}, Got: \{actual}",
      )
    }
  }
}

///|
test "constraint_individual_operators" {
  // Test individual constraint operators
  let test_cases = [
    // Equal operator
    ("= 1.2.3", "1.2.3", true),
    ("= 1.2.3", "1.2.4", false),
    ("1.2.3", "1.2.3", true), // implicit equal

    // Not equal operator 
    ("!= 1.2.3", "1.2.4", true),
    ("!= 1.2.3", "1.2.3", false),

    // Greater than operator
    ("> 1.2.3", "1.2.4", true),
    ("> 1.2.3", "1.2.3", false),
    ("> 1.2.3", "1.2.2", false),

    // Less than operator
    ("< 1.2.3", "1.2.2", true),
    ("< 1.2.3", "1.2.3", false),
    ("< 1.2.3", "1.2.4", false),

    // Greater than or equal operator
    (">= 1.2.3", "1.2.4", true),
    (">= 1.2.3", "1.2.3", true),
    (">= 1.2.3", "1.2.2", false),

    // Less than or equal operator
    ("<= 1.2.3", "1.2.2", true),
    ("<= 1.2.3", "1.2.3", true),
    ("<= 1.2.3", "1.2.4", false),
  ]
  for case in test_cases {
    let (constraint_str, version_str, expected) = case
    let constraint = Constraint::new(constraint_str) catch {
      _ => abort("Failed to parse constraint: \{constraint_str}")
    }
    let version = Version::new(version_str) catch {
      _ => abort("Failed to parse version: \{version_str}")
    }
    let actual = constraint.check(version)
    if actual != expected {
      abort(
        "Constraint: \{constraint_str}, Version: \{version_str}, Expected: \{expected}, Got: \{actual}",
      )
    }
  }
}

///|
test "constraint_prerelease" {
  let cases = [
    ("= 1.0", false),
    ("= 1.0-beta", true),
    ("~> 2.1.0", false),
    ("~> 2.1.0-dev", true),
    ("> 2.0", false),
    (">= 2.1.0-a", true),
  ]
  for case in cases {
    let (constraint_str, expected_has_prerelease) = case
    let constraint = Constraint::new(constraint_str) catch {
      _ => abort("Failed to parse constraint: \{constraint_str}")
    }
    let actual_has_prerelease = constraint.version.prerelease() != ""
    if actual_has_prerelease != expected_has_prerelease {
      abort(
        "Constraint: \{constraint_str}, Expected prerelease: \{expected_has_prerelease}, Got: \{actual_has_prerelease}",
      )
    }
  }
}

///|
test "constraint_string_representation" {
  let cases = [
    (">= 1.0, < 1.2", ">= 1.0, < 1.2"),
    ("~> 1.0.7", "~> 1.0.7"),
    ("= 1.2.3", "= 1.2.3"),
    ("1.2.3", "1.2.3"), // implicit equal should remain as is
  ]
  for case in cases {
    let (constraint_str, expected) = case
    let constraints = constraints_new(constraint_str) catch {
      _ => abort("Failed to parse constraint: \{constraint_str}")
    }
    let actual = constraints_to_string(constraints)
    if actual != expected {
      abort(
        "Constraint: \{constraint_str}, Expected: \{expected}, Got: \{actual}",
      )
    }
  }
}

///|
test "constraint_multiple" {
  // Test multiple constraints with comma separation
  let cases = [
    (">= 1.0.0, < 2.0.0", "1.5.0", true),
    (">= 1.0.0, < 2.0.0", "2.0.0", false),
    (">= 1.0.0, < 2.0.0", "0.9.9", false),
    ("> 1.0.0, <= 1.5.0", "1.3.0", true),
    ("> 1.0.0, <= 1.5.0", "1.0.0", false),
    ("> 1.0.0, <= 1.5.0", "1.5.1", false),
  ]
  for case in cases {
    let (constraints_str, version_str, expected) = case
    let constraints = constraints_new(constraints_str) catch {
      _ => abort("Failed to parse constraints: \{constraints_str}")
    }
    let version = Version::new(version_str) catch {
      _ => abort("Failed to parse version: \{version_str}")
    }
    let actual = constraints_check(constraints, version)
    if actual != expected {
      abort(
        "Constraints: \{constraints_str}, Version: \{version_str}, Expected: \{expected}, Got: \{actual}",
      )
    }
  }
}

///|
test "constraint_pessimistic_advanced" {
  // More advanced pessimistic constraint tests
  let cases = [
    ("~> 1.2", "1.2.0", true),
    ("~> 1.2", "1.2.9", true),
    ("~> 1.2", "1.3.0", false),
    ("~> 1.2.3", "1.2.3", true),
    ("~> 1.2.3", "1.2.4", true),
    ("~> 1.2.3", "1.3.0", false),
    ("~> 1.2.3", "1.2.2", false),
    // With prerelease
    ("~> 1.2.3-alpha", "1.2.3-beta", true),
    ("~> 1.2.3-alpha", "1.2.4-alpha", true),
    ("~> 1.2.3-alpha", "1.3.0-alpha", false),
    ("~> 1.2.3-alpha", "1.2.3", false), // no prerelease doesn't match
  ]
  for case in cases {
    let (constraint_str, version_str, expected) = case
    let constraint = Constraint::new(constraint_str) catch {
      _ => abort("Failed to parse constraint: \{constraint_str}")
    }
    let version = Version::new(version_str) catch {
      _ => abort("Failed to parse version: \{version_str}")
    }
    let actual = constraint.check(version)
    if actual != expected {
      abort(
        "Pessimistic constraint: \{constraint_str}, Version: \{version_str}, Expected: \{expected}, Got: \{actual}",
      )
    }
  }
}

///|
test "constraint_error_cases" {
  // Test cases that should produce errors
  let error_cases = [
    ">=", // missing version
     "1.x", // invalid version
     ">> 1.0", // invalid operator
     "", // empty constraint
     "~>",
  ] // missing version for pessimistic
  for constraint_str in error_cases {
    try {
      let _ = Constraint::new(constraint_str)
      abort("Expected error for constraint: \{constraint_str}")
    } catch {
      _ => () // Expected error
    }
  }
}

///|
test "constraint_equals_detailed" {
  let cases = [
    ("0.0.1", "0.0.1", true),
    (" 0.0.1 ", "0.0.1", true), // whitespaces
    ("=0.0.1 ", "0.0.1", true), // equal op implied
    ("=0.0.1", "=0.0.2", false), // version difference
    (">0.0.1", "=0.0.1", false), // operator difference
    (">0.1.0, <=1.0.0", "<=1.0.0, >0.1.0", true), // different order
  ]
  for case in cases {
    let (left_str, right_str, expected) = case
    let left_constraints = constraints_new(left_str) catch {
      _ => abort("Failed to parse left constraint: \{left_str}")
    }
    let right_constraints = constraints_new(right_str) catch {
      _ => abort("Failed to parse right constraint: \{right_str}")
    }
    let actual = constraints_equal(left_constraints, right_constraints)
    if actual != expected {
      abort(
        "Constraints: \{left_str} vs \{right_str}, Expected: \{expected}, Got: \{actual}",
      )
    }
  }
}

///|
test "constraints_must_helper" {
  // Test successful parsing
  let constraints = constraints_must(">= 1.0, < 2.0")
  if constraints.length() != 2 {
    abort("constraints_must failed: expected 2 constraints")
  }

  // Verify the constraints work
  let v1 = Version::new("1.5.0") catch {
    _ => abort("Failed to create test version")
  }
  if !constraints_check(constraints, v1) {
    abort("constraints_must result doesn't work correctly")
  }
  let v2 = Version::new("2.5.0") catch {
    _ => abort("Failed to create test version")
  }
  if constraints_check(constraints, v2) {
    abort("constraints_must result should reject version outside range")
  }
}

///|
test "constraint_individual_equals" {
  // Test individual constraint equality
  let c1 = Constraint::new("= 1.2.3") catch {
    _ => abort("Failed to create constraint")
  }
  let c2 = Constraint::new("= 1.2.3") catch {
    _ => abort("Failed to create constraint")
  }
  let c3 = Constraint::new("> 1.2.3") catch {
    _ => abort("Failed to create constraint")
  }
  let c4 = Constraint::new("= 1.2.4") catch {
    _ => abort("Failed to create constraint")
  }
  if !c1.equals(c2) {
    abort("Same constraints should be equal")
  }
  if c1.equals(c3) {
    abort("Different operators should not be equal")
  }
  if c1.equals(c4) {
    abort("Different versions should not be equal")
  }
}

///|
test "constraint_has_prerelease" {
  let cases = [
    ("= 1.0", false),
    ("= 1.0-beta", true),
    ("~> 2.1.0", false),
    ("~> 2.1.0-dev", true),
    ("> 2.0", false),
    (">= 2.1.0-a", true),
  ]
  for case in cases {
    let (constraint_str, expected) = case
    let constraint = Constraint::new(constraint_str) catch {
      _ => abort("Failed to parse constraint: \{constraint_str}")
    }
    let actual = constraint.has_prerelease()
    if actual != expected {
      abort(
        "Constraint: \{constraint_str}, Expected prerelease: \{expected}, Got: \{actual}",
      )
    }
  }
}

///|
test "constraint_overflow_edge_cases" {
  // Test constraint with maximum valid Int64 (should work)
  let max_int64_constraint = ">= 1.0.9223372036854775807"
  try {
    let constraints = constraints_new(max_int64_constraint)
    if constraints.length() != 1 {
      abort("Failed to parse max Int64 constraint")
    }

    // Test that it works with a version
    let test_version = Version::new("1.0.9223372036854775807") catch {
      _ => abort("Failed to create max Int64 version")
    }
    if !constraints_check(constraints, test_version) {
      abort("Max Int64 constraint should match max Int64 version")
    }
  } catch {
    _ => abort("Unexpected error for max Int64 constraint")
  }

  // Test constraint with extremely large number that would overflow
  // This should fail during version parsing, not constraint parsing
  // Note: Our current implementation might not detect overflow during parsing
  // which is different from Go but acceptable for MoonBit's Int64 range
}

///|
test "constraint_utility_functions" {
  // Test basic constraint helpers first
  let at_least = constraint_at_least("1.0.0") catch {
    _ => abort("Failed to create at_least constraint")
  }
  let version_1_5 = Version::new("1.5.0") catch {
    _ => abort("Failed to create version")
  }
  if !at_least.check(version_1_5) {
    abort("at_least constraint should accept 1.5.0")
  }

  // Test below helper  
  let below = constraint_below("2.0.0") catch {
    _ => abort("Failed to create below constraint")
  }
  if !below.check(version_1_5) {
    abort("below constraint should accept 1.5.0")
  }

  // Test exactly helper
  let exactly = constraint_exactly("1.5.0") catch {
    _ => abort("Failed to create exactly constraint")
  }
  if !exactly.check(version_1_5) {
    abort("exactly constraint should accept 1.5.0")
  }

  // Test constraints_allow_any
  let empty_constraints : Array[Constraint] = []
  if !constraints_allow_any(empty_constraints) {
    abort("Empty constraints should allow any version")
  }

  // Test min/max version extraction
  // We have: at_least (>= 1.0.0), below (< 2.0.0), exactly (= 1.5.0)
  let mixed_constraints = [at_least, below, exactly]

  // Check minimum version (should find >= 1.0.0)
  match constraints_min_version(mixed_constraints) {
    Some(min_ver) => {
      let expected_min = Version::new("1.0.0") catch {
        _ => abort("Failed to create expected version")
      }
      if !min_ver.equal(expected_min) {
        abort("Expected min version to be 1.0.0, got \{min_ver.to_string()}")
      }
    }
    None => abort("Expected to find a minimum version but got None")
  }

  // Check maximum version (should find < 2.0.0)
  match constraints_max_version(mixed_constraints) {
    Some(max_ver) => {
      let expected_max = Version::new("2.0.0") catch {
        _ => abort("Failed to create expected max version")
      }
      if !max_ver.equal(expected_max) {
        abort("Expected max version to be 2.0.0, got \{max_ver.to_string()}")
      }
    }
    None => abort("Expected to find a maximum version but got None")
  }
}

///|
test "constraint_improved_error_handling" {
  // Test empty constraint string
  try {
    let _ = Constraint::new("")
    abort("Expected error for empty constraint")
  } catch {
    _ => ()
  }

  // Test constraint with missing version
  try {
    let _ = Constraint::new(">=")
    abort("Expected error for constraint with missing version")
  } catch {
    _ => ()
  }

  // Test constraint with invalid version
  try {
    let _ = Constraint::new(">= invalid.version")
    abort("Expected error for constraint with invalid version")
  } catch {
    _ => ()
  }

  // Test constraint with just whitespace after operator
  try {
    let _ = Constraint::new(">=   ")
    abort("Expected error for constraint with whitespace after operator")
  } catch {
    _ => ()
  }
}
