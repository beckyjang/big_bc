const fs = require('fs');
const args = process.argv.slice(2);
const filepath = args[0];

try {
    let folderJSON = JSON.parse(fs.readFileSync(filepath));
    // console.log(folderJSON);

    let folderNames = [];
    for (let i in folderJSON.folders) {
        folderNames.push(folderJSON.folders[i].name);
    }
    console.log(folderNames.join("\n"));


} catch (e) {
    console.log(e);
}

// function getFolderList(foldersJson) {
//     let folderNames = [];
//     for (let i in foldersJson.folders) {
//         folderNames.push(foldersJson.folders[i].path);
//         // folderNames += foldersJson.folders[i].path;
//       }
//     return folderNames;
// }