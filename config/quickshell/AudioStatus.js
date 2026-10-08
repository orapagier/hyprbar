.pragma library

function headset(sink, route, bluetoothDevices) {
    if (!sink) return false;
    let props = Object.assign({}, sink.properties || {}, route ? route.properties || {} : {});
    let active = route ? route.active_port : "";
    let portName = typeof active === "string" ? active : active ? active.name || "" : "";
    let port = route && Array.isArray(route.ports) ? route.ports.find(p => p.name === portName) : null;
    let portText = [portName, port ? port.description : ""].join(" ").toLowerCase();
    if (/headphone|headset|earphone|earbud/.test(portText)) return true;
    // A laptop's speaker and headphone jack can share the same PipeWire node.
    if (/speaker|hdmi|displayport|lineout|line-out/.test(portText)) return false;
    let factor = String(props["device.form-factor"] || "").toLowerCase();
    if (/headphone|headset|earphone|earbud/.test(factor)) return true;
    if (/^(speaker|tv|hifi|car)$/.test(factor)) return false;
    let description = [sink.name, sink.description, props["device.icon-name"], props["media.icon-name"], props["device.product.name"], props["api.bluez5.profile"]].join(" ").toLowerCase();
    if (/headphone|headset|earphone|earbud|airpods/.test(description)) return true;
    let address = String(props["api.bluez5.address"] || props["device.string"] || "").toLowerCase();
    let name = String(sink.name || "").toLowerCase();
    return (bluetoothDevices || []).some(device => {
        let deviceAddress = String(device.address || "").toLowerCase();
        if (!device.connected || !deviceAddress) return false;
        let matches = address === deviceAddress || name.includes(deviceAddress.replace(/:/g, "_"));
        return matches && /headphone|headset|earphone|earbud/.test(String(device.icon || "").toLowerCase());
    });
}

function icon(isHeadset, muted, volume) {
    // Material Design glyphs match Android's speaker and headset silhouettes.
    if (isHeadset) return "\uDB80\uDECE"; // headset, U+F02CE
    if (muted) return "\uDB81\uDD81"; // volume-off, U+F0581
    if (volume <= 0) return "\uDB81\uDD7F"; // volume-low, U+F057F
    if (volume < 0.5) return "\uDB81\uDD80"; // volume-medium, U+F0580
    return "\uDB81\uDD7E"; // volume-high, U+F057E
}
