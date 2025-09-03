// Copyright (c) HashiCorp, Inc.
// Copyright (c) 2025 International Digital Economy Academy
// SPDX-License-Identifier: MPL-2.0

///|
fn main {
  println("MoonBit Version Library Demo")
  println("============================")

  // Test basic version parsing and comparison
  println("\n1. Version Parsing and Comparison:")
  test_version_parsing()

  // Test version collection sorting  
  println("\n2. Version Collection Sorting:")
  test_version_sorting()

  // Test constraint checking
  println("\n3. Version Constraints:")
  test_version_constraints()

  // Test semver vs regular version parsing
  println("\n4. SemVer vs Regular Version Parsing:")
  test_semver_vs_regular()

  // Test prerelease handling
  println("\n5. Prerelease Version Handling:")
  test_prerelease_handling()

  // Debug pessimistic constraint issue
  println("\n5.5. Debug Pessimistic Constraint:")
  debug_pessimistic_constraint()

  // Test must helpers and error handling
  println("\n6. Must Helpers and Error Handling:")
  test_must_helpers()
  println("\n7. JSON and Database Conversion:")
  test_json_and_db_conversion()
  println("\n8. New Utility Functions:")
  test_new_utilities()
}

///|
fn test_version_parsing() -> Unit {
  let version_strings = [
    "1.2.3", "2.0.0-alpha", "1.5.0+build.123", "v3.1.4", "1.0.0-beta.1+exp.sha.5114f85",
  ]
  for version_str in version_strings {
    println("Parsing version: \{version_str}")
    try {
      let v = @version.Version::new(version_str)
      println("  Canonical: \{v.to_string()}")
      let segs = v.segments()
      println("  Major.Minor.Patch: \{segs[0]}.\{segs[1]}.\{segs[2]}")
      println("  Prerelease: '\{v.prerelease()}'")
      println("  Metadata: '\{v.metadata()}'")
      println("  Original: '\{v.original()}'")
    } catch {
      _ => println("  Error: error parsing version")
    }
    println("")
  }
}

///|
fn test_version_sorting() -> Unit {
  let version_strings = ["1.1.0", "2.0.0", "1.0.0", "1.2.0", "1.1.5", "2.1.0"]
  let separator = ", "
  println("Original order: \{version_strings.join(separator)}")
  try {
    let sorted = @version.collection_from_strings(version_strings)
    let sorted_strings : Array[String] = []
    for v in sorted {
      sorted_strings.push(v.to_string())
    }
    println("Sorted order: \{sorted_strings.join(separator)}")
  } catch {
    _ => println("Error sorting: error creating versions")
  }
}

///|
fn test_version_constraints() -> Unit {
  try {
    let test_version = @version.Version::new("1.5.0")
    let constraint_strings = [
      ">= 1.0.0", "< 2.0.0", "~> 1.4", "!= 1.5.0", "= 1.5.0", "~> 1.5.0",
    ]
    println("Testing version \{test_version.to_string()} against constraints:")
    for constraint_str in constraint_strings {
      try {
        let constraint = @version.Constraint::new(constraint_str)
        let satisfies = constraint.check(test_version)
        let result = if satisfies { "PASS" } else { "FAIL" }
        println("  \{constraint_str}: \{result}")
      } catch {
        _ => println("  \{constraint_str}: Error - invalid constraint")
      }
    }

    // Test multiple constraints
    println("\nTesting multiple constraints (>= 1.0.0, < 2.0.0):")
    try {
      let constraints = @version.constraints_new(">= 1.0.0, < 2.0.0")
      let satisfies = @version.constraints_check(constraints, test_version)
      let result = if satisfies { "PASS" } else { "FAIL" }
      println("  Combined constraints: \{result}")
    } catch {
      _ => println("  Error parsing multiple constraints")
    }
  } catch {
    _ => println("Error creating test version")
  }
}

///|
fn test_new_utilities() -> Unit {
  try {
    let version = @version.Version::new("1.2.3-beta+build.123")
    println("Test version: \{version.to_string()}")

    // Test version stability checks
    println("  is_stable(): \{version.is_stable()}")
    println("  is_prerelease(): \{version.is_prerelease()}")

    // Test version component accessors
    println("  major(): \{version.major()}")
    println("  minor(): \{version.minor()}")
    println("  patch(): \{version.patch()}")

    // Test version increment functions
    try {
      let v_major = version.increment_major()
      let v_minor = version.increment_minor()
      let v_patch = version.increment_patch()
      println("  increment_major(): \{v_major.to_string()}")
      println("  increment_minor(): \{v_minor.to_string()}")
      println("  increment_patch(): \{v_patch.to_string()}")
    } catch {
      _ => println("  Error incrementing versions")
    }

    // Test constraint utility functions
    println("\nConstraint utility functions:")
    try {
      let at_least = @version.constraint_at_least("1.0.0")
      let below = @version.constraint_below("2.0.0")
      let exactly = @version.constraint_exactly("1.5.0")
      let pessimistic = @version.constraint_pessimistic("1.2")
      let test_version = @version.Version::new("1.5.0")
      println("  Testing version 1.5.0 against constraint helpers:")
      println(
        "    constraint_at_least('1.0.0'): \{at_least.check(test_version)}",
      )
      println("    constraint_below('2.0.0'): \{below.check(test_version)}")
      println("    constraint_exactly('1.5.0'): \{exactly.check(test_version)}")
      let test_version_2 = @version.Version::new("1.3.0")
      println("  Testing version 1.3.0 against pessimistic constraint:")
      println(
        "    constraint_pessimistic('1.2'): \{pessimistic.check(test_version_2)}",
      )

      // Test range constraints
      let range = @version.constraint_range("1.0.0", "2.0.0")
      println("  Testing constraint_range('1.0.0', '2.0.0'):")
      println(
        "    version 1.5.0 satisfies: \{@version.constraints_check(range, test_version)}",
      )

      // Test constraints analysis
      let constraints = [at_least, below]
      match @version.constraints_min_version(constraints) {
        Some(min_ver) =>
          println("  Minimum version from constraints: \{min_ver.to_string()}")
        None => println("  No minimum version found")
      }
      match @version.constraints_max_version(constraints) {
        Some(max_ver) =>
          println("  Maximum version from constraints: \{max_ver.to_string()}")
        None => println("  No maximum version found")
      }
    } catch {
      _ => println("  Error testing constraint utilities")
    }
  } catch {
    _ => println("Error creating test version")
  }
}

///|
fn debug_pessimistic_constraint() -> Unit {
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
    try {
      let constraint = @version.Constraint::new(constraint_str)
      let version = @version.Version::new(version_str)
      let actual = constraint.check(version)
      let result = if actual == expected { "PASS" } else { "FAIL" }
      println(
        "  \{constraint_str} vs \{version_str}: Expected \{expected}, Got \{actual} [\{result}]",
      )
      if actual != expected {
        println("    ^^^ THIS IS THE FAILING TEST CASE ^^^")
        println("    Constraint si: \{constraint.version.si}")
        println("    Constraint segments: \{constraint.version.segments64()}")
        println("    Version segments: \{version.segments64()}")
        println(
          "    Loop should check i=0 to i<\{constraint.version.si - 1} (so \{constraint.version.si - 1} iterations)",
        )
      }
    } catch {
      _ => println("  Error testing \{constraint_str} vs \{version_str}")
    }
  }
}

///|
fn test_semver_vs_regular() -> Unit {
  let test_versions = ["1.7rc2", "v1.7rc2", "1.0-", "1.2.beta", "1.2.3alpha1"]
  for version_str in test_versions {
    println("Testing '\{version_str}':")

    // Try regular version parsing
    try {
      let v = @version.Version::new(version_str)
      println("  Regular version: SUCCESS - \{v.to_string()}")
    } catch {
      _ => println("  Regular version: FAILED")
    }

    // Try semver parsing
    try {
      let v = @version.Version::new_semver(version_str)
      println("  SemVer version: SUCCESS - \{v.to_string()}")
    } catch {
      _ => println("  SemVer version: FAILED")
    }
    println("")
  }
}

///|
fn test_prerelease_handling() -> Unit {
  let prerelease_versions = [
    "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-rc.1", "1.0.0",
  ]

  // Create versions and show sorting
  println("Prerelease versions in sorted order:")
  try {
    let versions = @version.collection_from_strings(prerelease_versions)
    for v in versions {
      let pre = v.prerelease()
      let pre_info = if pre == "" {
        "(release)"
      } else {
        "(prerelease: \{pre})"
      }
      println("  \{v.to_string()} \{pre_info}")
    }
  } catch {
    _ => println("Error creating prerelease versions")
  }

  // Show prerelease constraint behavior
  println("\nPrerelease constraint behavior:")
  try {
    let constraint = @version.Constraint::new("~> 1.0.0-alpha")
    let test_versions = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-beta", "1.0.0"]
    for version_str in test_versions {
      try {
        let version = @version.Version::new(version_str)
        let satisfies = constraint.check(version)
        let result = if satisfies { "PASS" } else { "FAIL" }
        println("  ~> 1.0.0-alpha vs \{version_str}: \{result}")
      } catch {
        _ => println("  Error parsing version \{version_str}")
      }
    }
  } catch {
    _ => println("Error creating prerelease constraint")
  }
}

///|
fn test_must_helpers() -> Unit {
  println("Testing must helpers with valid input:")
  let v1 = @version.Version::must("1.2.3")
  println("  Version::must('1.2.3'): \{v1.to_string()}")
  let v2 = @version.Version::must_semver("1.2.3")
  println("  Version::must_semver('1.2.3'): \{v2.to_string()}")
  let constraints = @version.constraints_must(">= 1.0.0, < 2.0.0")
  println(
    "  constraints_must('>= 1.0.0, < 2.0.0'): \{constraints.length()} constraints",
  )
  println(
    "\nMust helpers will abort on invalid input (not demonstrated to avoid crash)",
  )
  println("  Version::must('invalid') would abort with parse error")
  println("  Version::must_semver('1.7rc2') would abort with parse error")
}

///|
fn test_json_and_db_conversion() -> Unit {
  try {
    let version = @version.Version::new("1.2.3-beta+build.123")
    println("Original version: \{version.to_string()}")

    // JSON conversion
    let json_str = version.to_json()
    println("JSON representation: \{json_str}")
    try {
      let parsed_from_json = @version.Version::from_json(json_str)
      println("Parsed from JSON: \{parsed_from_json.to_string()}")
      let are_equal = version.equal(parsed_from_json)
      println("JSON round-trip successful: \{are_equal}")
    } catch {
      _ => println("Error parsing from JSON")
    }

    // Database conversion
    let db_str = version.to_db_string()
    println("Database representation: \{db_str}")
    try {
      let parsed_from_db = @version.Version::from_db_string(db_str)
      println("Parsed from DB: \{parsed_from_db.to_string()}")
      let are_equal = version.equal(parsed_from_db)
      println("Database round-trip successful: \{are_equal}")
    } catch {
      _ => println("Error parsing from database string")
    }
  } catch {
    _ => println("Error creating test version")
  }
}
