module.exports = async (promise) => {
    try {
        console.log(`start promise`);
        await promise;
        console.log(`start promise ing`);
        assert.fail("Expected revert not received");
        console.log(`start promise end`);
    } catch (error) {
        console.log(`catch error`);
        const revertFound = error.message.search("revert") > -1;
        console.log(`error msg:${error.message}`);
        assert(revertFound, `Expected "revert", got ${error} instead`);
    }
};
