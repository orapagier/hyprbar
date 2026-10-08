.pragma library

function easter(year) {
    let a = year % 19, b = Math.floor(year / 100), c = year % 100;
    let d = Math.floor(b / 4), e = b % 4;
    let f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
    let h = (19 * a + b - d - g + 15) % 30;
    let i = Math.floor(c / 4), k = c % 4;
    let l = (32 + 2 * e + 2 * i - h - k) % 7;
    let m = Math.floor((a + 11 * h + 22 * l) / 451);
    let n = h + l - 7 * m + 114;
    return new Date(year, Math.floor(n / 31) - 1, n % 31 + 1);
}
function holidays(year) {
    // Port the dates and rules in the user's existing Philippine calendar.
    let result = {
        "1-1": ["New Year's Day", "regular"], "4-9": ["Araw ng Kagitingan", "regular"],
        "5-1": ["Labor Day", "regular"], "6-12": ["Independence Day", "regular"],
        "11-30": ["Bonifacio Day", "regular"], "12-25": ["Christmas Day", "regular"],
        "12-30": ["Rizal Day", "regular"], "8-21": ["Ninoy Aquino Day", "special"],
        "11-1": ["All Saints' Day", "special"], "11-2": ["All Souls' Day", "special"],
        "12-8": ["Feast of the Immaculate Conception", "special"], "12-24": ["Christmas Eve", "special"],
        "12-31": ["Last Day of the Year", "special"], "2-25": ["EDSA People Power Anniversary", "working"]
    };
    let last = new Date(year, 7, 31);
    result["8-" + (31 - (last.getDay() + 6) % 7)] = ["National Heroes Day", "regular"];
    let sunday = easter(year);
    for (let entry of [[-3,"Maundy Thursday","regular"],[-2,"Good Friday","regular"],[-1,"Black Saturday","special"]]) {
        let date = new Date(year, sunday.getMonth(), sunday.getDate() + entry[0]);
        result[(date.getMonth()+1) + "-" + date.getDate()] = [entry[1],entry[2]];
    }
    let cny = {2024: "2-10", 2025: "1-29", 2026: "2-17", 2027: "2-6", 2028: "1-26"};
    if (cny[year]) result[cny[year]] = ["Chinese New Year", "special"];
    if (year === 2026) { result["3-20"] = ["Eid'l Fitr", "regular"]; result["5-27"] = ["Eid'l Adha", "regular"]; }
    return result;
}
