var mut view: UIView

match view {
	is UIImageView							=> console.log("It's an image view")
	is UILabel		with label: UILabel		=> console.log("It's a label")
	is UITableView	with mut tblv			{
		var dyn sectionCount = tblv.numberOfSections()
		console.log("It's a table view with \(sectionCount) sections")
	}
	else									=> console.log("It's some other UIView or subclass")
}