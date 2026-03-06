var stats = {
    type: "GROUP",
name: "Global Information",
path: "",
pathFormatted: "group_missing-name-b06d1",
stats: {
    "name": "Global Information",
    "numberOfRequests": {
        "total": "13000",
        "ok": "13000",
        "ko": "0"
    },
    "minResponseTime": {
        "total": "20",
        "ok": "20",
        "ko": "-"
    },
    "maxResponseTime": {
        "total": "2816",
        "ok": "2816",
        "ko": "-"
    },
    "meanResponseTime": {
        "total": "53",
        "ok": "53",
        "ko": "-"
    },
    "standardDeviation": {
        "total": "125",
        "ok": "125",
        "ko": "-"
    },
    "percentiles1": {
        "total": "34",
        "ok": "34",
        "ko": "-"
    },
    "percentiles2": {
        "total": "42",
        "ok": "42",
        "ko": "-"
    },
    "percentiles3": {
        "total": "85",
        "ok": "85",
        "ko": "-"
    },
    "percentiles4": {
        "total": "1040",
        "ok": "1040",
        "ko": "-"
    },
    "group1": {
    "name": "t < 800 ms",
    "count": 12857,
    "percentage": 99
},
    "group2": {
    "name": "800 ms < t < 1200 ms",
    "count": 135,
    "percentage": 1
},
    "group3": {
    "name": "t > 1200 ms",
    "count": 8,
    "percentage": 0
},
    "group4": {
    "name": "failed",
    "count": 0,
    "percentage": 0
},
    "meanNumberOfRequestsPerSecond": {
        "total": "361.111",
        "ok": "361.111",
        "ko": "-"
    }
},
contents: {
"req_client-credenti-35a47": {
        type: "REQUEST",
        name: "Client credentials grant type",
path: "Client credentials grant type",
pathFormatted: "req_client-credenti-35a47",
stats: {
    "name": "Client credentials grant type",
    "numberOfRequests": {
        "total": "13000",
        "ok": "13000",
        "ko": "0"
    },
    "minResponseTime": {
        "total": "20",
        "ok": "20",
        "ko": "-"
    },
    "maxResponseTime": {
        "total": "2816",
        "ok": "2816",
        "ko": "-"
    },
    "meanResponseTime": {
        "total": "53",
        "ok": "53",
        "ko": "-"
    },
    "standardDeviation": {
        "total": "125",
        "ok": "125",
        "ko": "-"
    },
    "percentiles1": {
        "total": "34",
        "ok": "34",
        "ko": "-"
    },
    "percentiles2": {
        "total": "42",
        "ok": "42",
        "ko": "-"
    },
    "percentiles3": {
        "total": "85",
        "ok": "85",
        "ko": "-"
    },
    "percentiles4": {
        "total": "1040",
        "ok": "1040",
        "ko": "-"
    },
    "group1": {
    "name": "t < 800 ms",
    "count": 12857,
    "percentage": 99
},
    "group2": {
    "name": "800 ms < t < 1200 ms",
    "count": 135,
    "percentage": 1
},
    "group3": {
    "name": "t > 1200 ms",
    "count": 8,
    "percentage": 0
},
    "group4": {
    "name": "failed",
    "count": 0,
    "percentage": 0
},
    "meanNumberOfRequestsPerSecond": {
        "total": "361.111",
        "ok": "361.111",
        "ko": "-"
    }
}
    }
}

}

function fillStats(stat){
    $("#numberOfRequests").append(stat.numberOfRequests.total);
    $("#numberOfRequestsOK").append(stat.numberOfRequests.ok);
    $("#numberOfRequestsKO").append(stat.numberOfRequests.ko);

    $("#minResponseTime").append(stat.minResponseTime.total);
    $("#minResponseTimeOK").append(stat.minResponseTime.ok);
    $("#minResponseTimeKO").append(stat.minResponseTime.ko);

    $("#maxResponseTime").append(stat.maxResponseTime.total);
    $("#maxResponseTimeOK").append(stat.maxResponseTime.ok);
    $("#maxResponseTimeKO").append(stat.maxResponseTime.ko);

    $("#meanResponseTime").append(stat.meanResponseTime.total);
    $("#meanResponseTimeOK").append(stat.meanResponseTime.ok);
    $("#meanResponseTimeKO").append(stat.meanResponseTime.ko);

    $("#standardDeviation").append(stat.standardDeviation.total);
    $("#standardDeviationOK").append(stat.standardDeviation.ok);
    $("#standardDeviationKO").append(stat.standardDeviation.ko);

    $("#percentiles1").append(stat.percentiles1.total);
    $("#percentiles1OK").append(stat.percentiles1.ok);
    $("#percentiles1KO").append(stat.percentiles1.ko);

    $("#percentiles2").append(stat.percentiles2.total);
    $("#percentiles2OK").append(stat.percentiles2.ok);
    $("#percentiles2KO").append(stat.percentiles2.ko);

    $("#percentiles3").append(stat.percentiles3.total);
    $("#percentiles3OK").append(stat.percentiles3.ok);
    $("#percentiles3KO").append(stat.percentiles3.ko);

    $("#percentiles4").append(stat.percentiles4.total);
    $("#percentiles4OK").append(stat.percentiles4.ok);
    $("#percentiles4KO").append(stat.percentiles4.ko);

    $("#meanNumberOfRequestsPerSecond").append(stat.meanNumberOfRequestsPerSecond.total);
    $("#meanNumberOfRequestsPerSecondOK").append(stat.meanNumberOfRequestsPerSecond.ok);
    $("#meanNumberOfRequestsPerSecondKO").append(stat.meanNumberOfRequestsPerSecond.ko);
}
