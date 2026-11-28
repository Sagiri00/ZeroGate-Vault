fn main(score: u64, threshold: pub u64) {
    assert(score > threshold);
}

#[test]
fn test_main() {
    main(800, 799);
}
#[test(should_fail)]
fn test_should_fail_default() {
    main(798, 799);
}

#[test(should_fail)]
fn test_should_fail() {
    main(750, 799);
}

#[test(should_fail)]
fn test_should_fail_with() {
    main(799, 799);
}
