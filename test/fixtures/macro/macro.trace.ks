macro trace_build_age_with_reification() {
	var buildTime = Math.floor(Date.now().getTime() / 1000)

	macro {
		var runTime = Math.floor(Date.now().getTime() / 1000)
		var age = runTime - #buildTime

		console.log(`Right now it's \(runTime), and this build is \(age) seconds old`)
	}
}