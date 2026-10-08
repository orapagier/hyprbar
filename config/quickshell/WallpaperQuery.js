.pragma library

function sources(text) {
    let result = {};
    for (let line of text.split("\n")) {
        // awww prefixes outputs with its namespace (empty by default).
        let match = line.match(/(?:^|: )([^:]+): \d+x\d+.*currently displaying: image: (.+)$/);
        if (match) result[match[1]] = "file://" + match[2].split("/").map(encodeURIComponent).join("/");
    }
    return result;
}
