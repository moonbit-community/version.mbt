// Copyright (c) HashiCorp, Inc.
// Copyright (c) 2025 International Digital Economy Academy
// SPDX-License-Identifier: MPL-2.0

///|
test "collection_sort" {
  let versions_raw = ["1.1.1", "1.0", "1.2", "2", "0.7.1"]
  let versions : Array[Version] = []
  for raw in versions_raw {
    let v = Version::new(raw) catch {
      _ => abort("Failed to parse version: \{raw}")
    }
    versions.push(v)
  }
  collection_sort(versions)
  let actual : Array[String] = []
  for v in versions {
    actual.push(v.to_string())
  }
  let expected = ["0.7.1", "1.0.0", "1.1.1", "1.2.0", "2.0.0"]
  if actual != expected {
    abort("Expected: \{expected}, Got: \{actual}")
  }
}

///|
test "collection_from_strings" {
  let version_strings = ["2.1.0", "1.0.0", "1.5.0", "0.9.0", "2.0.0"]
  let sorted_versions = collection_from_strings(version_strings) catch {
    _ => abort("Failed to create collection from strings")
  }
  let actual : Array[String] = []
  for v in sorted_versions {
    actual.push(v.to_string())
  }
  let expected = ["0.9.0", "1.0.0", "1.5.0", "2.0.0", "2.1.0"]
  if actual != expected {
    abort("Expected: \{expected}, Got: \{actual}")
  }
}

///|
test "collection_is_sorted" {
  // Test with sorted collection
  let sorted_versions = [
    Version::new("1.0.0") catch {
      _ => abort("Failed to parse")
    },
    Version::new("1.1.0") catch {
      _ => abort("Failed to parse")
    },
    Version::new("2.0.0") catch {
      _ => abort("Failed to parse")
    },
  ]
  if !collection_is_sorted(sorted_versions) {
    abort("Expected collection to be sorted")
  }

  // Test with unsorted collection
  let unsorted_versions = [
    Version::new("2.0.0") catch {
      _ => abort("Failed to parse")
    },
    Version::new("1.0.0") catch {
      _ => abort("Failed to parse")
    },
    Version::new("1.1.0") catch {
      _ => abort("Failed to parse")
    },
  ]
  if collection_is_sorted(unsorted_versions) {
    abort("Expected collection to be unsorted")
  }
}

///|
test "collection_complex_versions" {
  let complex_versions = [
    "1.2.3-alpha.1", "1.2.3-alpha.2", "1.2.3-beta.1", "1.2.3", "1.2.4-alpha.1", "1.3.0",
    "2.0.0-alpha.1", "2.0.0",
  ]
  let sorted_collection = collection_from_strings(complex_versions) catch {
    _ => abort("Failed to create collection")
  }
  if !collection_is_sorted(sorted_collection) {
    abort("Expected complex collection to be sorted")
  }

  // Test the actual order
  let actual : Array[String] = []
  for v in sorted_collection {
    actual.push(v.to_string())
  }
  let expected = [
    "1.2.3-alpha.1", "1.2.3-alpha.2", "1.2.3-beta.1", "1.2.3", "1.2.4-alpha.1", "1.3.0",
    "2.0.0-alpha.1", "2.0.0",
  ]
  if actual != expected {
    abort("Complex sort failed. Expected: \{expected}, Got: \{actual}")
  }
}

///|
test "collection_custom_sort" {
  let versions = [
    Version::new("1.0.0") catch {
      _ => abort("Failed to parse")
    },
    Version::new("2.0.0") catch {
      _ => abort("Failed to parse")
    },
    Version::new("1.5.0") catch {
      _ => abort("Failed to parse")
    },
  ]

  // Sort in reverse order
  collection_sort_by_fn(versions, fn(a, b) { b.compare(a) })
  let actual : Array[String] = []
  for v in versions {
    actual.push(v.to_string())
  }
  let expected = ["2.0.0", "1.5.0", "1.0.0"]
  if actual != expected {
    abort("Reverse sort failed. Expected: \{expected}, Got: \{actual}")
  }
}

///|
test "collection_empty" {
  let empty_versions : Array[Version] = []

  // Empty collection should be considered sorted
  if !collection_is_sorted(empty_versions) {
    abort("Empty collection should be sorted")
  }

  // Sorting empty collection should not fail
  collection_sort(empty_versions)
  if empty_versions.length() != 0 {
    abort("Empty collection should remain empty after sorting")
  }
}

///|
test "collection_single_version" {
  let single_version = [
    Version::new("1.2.3") catch {
      _ => abort("Failed to parse")
    },
  ]
  if !collection_is_sorted(single_version) {
    abort("Single version collection should be sorted")
  }
  collection_sort(single_version)
  if single_version.length() != 1 {
    abort("Single version collection should have one element after sorting")
  }
  if single_version[0].to_string() != "1.2.3" {
    abort("Single version should remain unchanged after sorting")
  }
}

///|
test "collection_duplicate_versions" {
  let versions_with_duplicates = [
    "1.0.0", "2.0.0", "1.0.0", // duplicate
     "1.5.0", "2.0.0", // duplicate
     "1.5.0", // duplicate
  ]
  let collection = collection_from_strings(versions_with_duplicates) catch {
    _ => abort("Failed to create collection from strings with duplicates")
  }

  // Should be sorted including duplicates
  if !collection_is_sorted(collection) {
    abort("Collection with duplicates should be sorted")
  }

  // All versions should be present (including duplicates)
  if collection.length() != 6 {
    abort("Collection should preserve all versions including duplicates")
  }
}

///|
test "collection_metadata_versions" {
  let versions_with_metadata = [
    "1.0.0+build.1", "1.0.0+build.2", "1.0.0", "1.0.1+build.1", "1.0.1",
  ]
  let collection = collection_from_strings(versions_with_metadata) catch {
    _ => abort("Failed to create collection from versions with metadata")
  }
  if !collection_is_sorted(collection) {
    abort("Collection with metadata should be sorted")
  }

  // Versions with same base but different metadata should be treated as equal in sorting
  // but preserved as separate entries
  if collection.length() != 5 {
    abort("Collection should preserve all metadata versions")
  }
}
