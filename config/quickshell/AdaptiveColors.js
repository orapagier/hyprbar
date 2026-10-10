.pragma library

function mix(a, b, amount) {
    return Qt.rgba(a.r + (b.r - a.r) * amount,
                   a.g + (b.g - a.g) * amount,
                   a.b + (b.b - a.b) * amount, 1);
}
function luminance(color) {
    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
    return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
}
function contrast(a, b) {
    let x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}
function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity); }

// Preserve bright hues when a pill can supply the contrasting backing.
function vibrantForeground(sample, accent) {
    let foreground = Qt.hsva(accent.hsvHue, accent.hsvSaturation,
                             Math.max(0.92, accent.hsvValue), 1);
    let backing = Qt.rgba(0.035, 0.04, 0.06, 1);
    for (let i = 0; i < 30 && contrast(foreground, backing) < 5.2; ++i)
        foreground = mix(foreground, Qt.rgba(1, 1, 1, 1), 0.04);
    return foreground;
}

function vibrantPalette(sample, accent, minimum, maximum) {
    let foreground = vibrantForeground(sample, accent);
    let base = Qt.rgba(0.035, 0.04, 0.06, 1);
    let background = mix(base, accent, 0.04);
    let opacity = 0.22;
    // Protect the bright foreground against the lightest sampled pixels,
    // including hover/selection fills and the pill's white glass highlight.
    function minimumContrast() {
        let result = 100;
        for (let state of [0, 1, 2]) {
            let fill = mix(background, foreground, state * 0.03);
            for (let under of [minimum, maximum]) {
                let composite = mix(under, fill, Math.min(0.96, opacity + state * 0.06));
                result = Math.min(result, contrast(foreground, mix(composite, Qt.rgba(1,1,1,1), 0.08)));
            }
        }
        return result;
    }
    while (opacity < 0.96 && minimumContrast() < 4.6)
        opacity = Math.min(0.96, opacity + 0.02);
    // Very dark source accents need a small brightness lift for glass highlights.
    for (let i = 0; i < 30 && minimumContrast() < 4.6; ++i)
        foreground = mix(foreground, Qt.rgba(1,1,1,1), 0.04);
    return {
        foreground: foreground,
        tint: alpha(background, opacity),
        hover: alpha(mix(background, foreground, 0.03), Math.min(0.96, opacity + 0.06)),
        selected: alpha(mix(background, foreground, 0.06), Math.min(0.96, opacity + 0.12)),
        outline: alpha(foreground, 0.24),
        selectedOutline: alpha(foreground, 0.55),
        glyphOutline: base
    };
}

function regionContrast(foreground, minimum, maximum) {
    let value = luminance(foreground), low = luminance(minimum), high = luminance(maximum);
    // Include intermediate tones: an average or two endpoint comparisons can
    // miss wallpaper pixels with exactly the glyph's brightness.
    if (value >= low && value <= high) return 1;
    return Math.min(contrast(foreground, minimum), contrast(foreground, maximum));
}

function glyphEdge(foreground) {
    let dark = Qt.rgba(0.015, 0.02, 0.03, 1), light = Qt.rgba(1, 1, 1, 1);
    return contrast(foreground, dark) >= contrast(foreground, light) ? dark : light;
}

function barePalette(sample, accent, minimum, maximum, style) {
    let original = style === "muted" ? Qt.rgba(0.62, 0.62, 0.62, 1)
                 : style === "vibrant" ? vibrantForeground(sample, accent) : accent;
    let dark = Qt.rgba(0.015, 0.02, 0.03, 1), light = Qt.rgba(1, 1, 1, 1);
    if (style === "muted") dark = Qt.rgba(0.02, 0.02, 0.02, 1);
    let darkScore = regionContrast(dark, minimum, maximum), lightScore = regionContrast(light, minimum, maximum);
    let target = darkScore > lightScore ? dark : light;
    // On textured regions neither polarity may work everywhere. Choose the
    // most readable fill for the average and protect its silhouette with an edge.
    if (Math.max(darkScore, lightScore) < 4.5)
        target = contrast(dark, sample) > contrast(light, sample) ? dark : light;
    let achievable = regionContrast(target, minimum, maximum);
    let textured = achievable < 4.5;
    let foreground = original;
    if (!textured) {
        // Change lightness while retaining hue and saturation. Mixing toward
        // white bleached colorful items, even when a richer shade was readable.
        let goal = Math.min(4.6, achievable * 0.99);
        let distance = 2;
        for (let i = 0; i <= 128; ++i) {
            let candidate = Qt.hsla(original.hslHue, original.hslSaturation, i / 128, 1);
            let delta = Math.abs(candidate.hslLightness - original.hslLightness);
            if (delta < distance && regionContrast(candidate, minimum, maximum) >= goal) {
                foreground = candidate;
                distance = delta;
            }
        }
    }
    // A textured region cannot be made readable by washing out the fill.
    // Preserve the accent and use a contrasting silhouette instead.
    // Keep the regular palette fields for consumers, but never solve bare
    // contrast by increasing a background that will not be drawn.
    let result = style === "vibrant" ? vibrantPalette(sample, accent, minimum, maximum)
                                     : palette(sample, accent, minimum, maximum, style);
    result.foreground = foreground;
    result.glyphHalo = regionContrast(foreground, minimum, maximum) < 4.5;
    result.glyphOutline = glyphEdge(foreground);
    return result;
}

function palette(sample, accent, minimum, maximum, style) {
    minimum = minimum || sample;
    maximum = maximum || sample;
    if (style === "vibrant-bare")
        return barePalette(sample, accent, minimum, maximum, "vibrant");
    if (style === "vibrant")
        return vibrantPalette(sample, accent, minimum, maximum);
    if (style && style.indexOf("bare-") === 0) {
        return barePalette(sample, accent, minimum, maximum, style.slice(5));
    }
    let light = luminance(sample) > 0.179;
    if (style === "muted") {
        let gray = 0.2126 * sample.r + 0.7152 * sample.g + 0.0722 * sample.b;
        sample = Qt.rgba(gray, gray, gray, 1);
        accent = Qt.rgba(0.62, 0.62, 0.62, 1);
    }
    let base = light ? Qt.rgba(0.98, 0.98, 1, 1) : Qt.rgba(0.055, 0.06, 0.085, 1);
    if (style === "muted") base = light ? Qt.rgba(0.98, 0.98, 0.98, 1) : Qt.rgba(0.065, 0.065, 0.065, 1);
    let emphasized = style === "emphasized";
    let background = mix(mix(sample, accent, emphasized ? 0.80 : 0.30), base, emphasized ? 0.22 : 0.55);
    let opacity = emphasized ? 0.38 : style === "muted" ? 0.10 : 0.22;
    let foreground = mix(accent, sample, 0.15);
    let target = light ? (style === "muted" ? Qt.rgba(0.035, 0.035, 0.035, 1) : Qt.rgba(0.025, 0.03, 0.045, 1)) : Qt.rgba(1, 1, 1, 1);
    // Start with translucent glass. Increase opacity only when the sampled
    // region's darkest/lightest pixels need more protection for legible text.
    function minimumContrast(fg, opacity) {
        let worst = light ? minimum : maximum;
        let result = 100;
        for (let state of [0, 1, 2]) {
            let fill = mix(background, fg, state * 0.03);
            let composite = mix(worst, fill, Math.min(0.96, opacity + state * 0.06));
            if (!light) composite = mix(composite, Qt.rgba(1, 1, 1, 1), 0.08);
            result = Math.min(result, contrast(fg, composite));
        }
        return result;
    }
    while (opacity < 0.86 && minimumContrast(target, opacity) < 5.2)
        opacity = Math.min(0.86, opacity + 0.04);
    for (let i = 0; i < 20 && minimumContrast(target, opacity) < 5.2; ++i)
        background = mix(background, base, 0.12);
    for (let i = 0; i < 40 && minimumContrast(foreground, opacity) < 5; ++i)
        foreground = mix(foreground, target, 0.12);
    return {
        foreground: foreground,
        tint: alpha(background, opacity),
        hover: alpha(mix(background, foreground, 0.03), Math.min(0.96, opacity + 0.06)),
        selected: alpha(mix(background, foreground, 0.06), Math.min(0.96, opacity + 0.12)),
        outline: alpha(foreground, style === "muted" ? 0.10 : 0.24),
        selectedOutline: alpha(emphasized ? accent : foreground, emphasized ? 0.70 : 0.55)
    };
}
