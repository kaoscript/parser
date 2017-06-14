macro trace_build_age_with_reification() {
	const buildTime = Math.floor(Date.now().getTime() / 1000)
	
	macro {
		const runTime = Math.floor(Date.now().getTime() / 1000)
		const age = runTime - #buildTime
		
		console.log(`Right now it's \(runTime), and this build is \(age) seconds old`)
	}
}