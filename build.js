import * as fs from 'fs'
import * as path from 'path'
import get_files from './get_files.js'

const files = [
  ...get_files('./domain-check-functions'),
  ...get_files('./domains'),
  ...get_files('./tables'),
  ...get_files('./helpers'),
  ...get_files('./views'),
  ...get_files('./event-triggers'),
  './init.sql',
]

let content = ''
for (const i in files) {
  const filepath = files[i]
  const data = fs.readFileSync(filepath, 'utf8')

  const title = path.parse(filepath).name.toUpperCase()
  const header =
    `/*
=================== ${title} =================== 
*/\n`
  content += header + data
}

const name = process.env.npm_package_name
const version = process.env.npm_package_version
const filepath = `./dist/${name}--${version}.sql`
fs.writeFileSync(filepath, content, 'utf8')

console.log('the file is generated and located in ' + filepath)
