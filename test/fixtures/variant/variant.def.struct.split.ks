struct SchoolPerson {
    variant kind: PersonKind
}
struct Student extends SchoolPerson(Student) {
    name: string
}