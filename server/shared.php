<?php
$USER = "admin";
$PASSWORD = "password";
?>

<style type="text/css">
.table {
    border: none;
    margin-bottom: 20px;
}
.table thead th {
    font-weight: bold;
    text-align: left;
    border: none;
    padding: 10px 15px;
    background: #d8d8d8;
    font-size: 14px;
}
.table thead tr th:first-child {
    border-radius: 8px 0 0 8px;
}
.table thead tr th:last-child {
    border-radius: 0 8px 8px 0;
}
.table tbody td {
    text-align: left;
    border: none;
    padding: 10px 15px;
    font-size: 14px;
    vertical-align: top;
}
.table tbody tr:nth-child(even){
    background: #f3f3f3;
}
.table tbody tr td:first-child {
    border-radius: 8px 0 0 8px;
}
.table tbody tr td:last-child {
    border-radius: 0 8px 8px 0;
}
</style>


<?php
ini_set('error_reporting', E_ALL);
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);

ini_set('upload_max_size' , '500M');
ini_set('post_max_size', '500M');
// ini_set('max_execution_time', '900';
?>


<?php
if ($_FILES && $_FILES["filename"]["error"]== UPLOAD_ERR_OK)
{
    $name = $_FILES["filename"]["name"];
    move_uploaded_file($_FILES["filename"]["tmp_name"], "/sharedfolders/temp_folder/shared/".$name);
    header('location:shared.php');
}

if (isset($_GET['delete'])) {
    $filename = $_GET['delete'];
    $cmd = "rm /sharedfolders/temp_folder/shared/". $filename;
    header('location:shared.php');
    shell_exec($cmd);
}
?>


<form method="post" enctype="multipart/form-data">
    <input type="file" name="filename" size="10" />
    <input type="submit" name="uploadBtn" value="Upload" />
</form>

<?php
function getFileList($dir)
{
    $retval = [];

    if(substr($dir, -1) != "/") {
        $dir .= "/";
    }

    $d = @dir($dir) or die("getFileList: Failed opening directory {$dir} for reading");
    while(FALSE !== ($entry = $d->read())) {
        if($entry{0} == ".") continue;
        if(is_dir("{$dir}{$entry}")) {
            $retval[] = [
                'name' => "{$entry}/",
                'type' => filetype("{$dir}{$entry}"),
                'size' => 0,
                'lastmod' => filemtime("{$dir}{$entry}")
            ];
        } elseif(is_readable("{$dir}{$entry}")) {
            $retval[] = [
                'name' => "{$entry}",
                'type' => mime_content_type("{$dir}{$entry}"),
                'size' => filesize("{$dir}{$entry}"),
                'lastmod' => filemtime("{$dir}{$entry}")
            ];
        }
    }
    $d->close();
    function compare_name($a, $b) { return strnatcmp($a['name'], $b['name']); }
    usort($retval, 'compare_name');

    return $retval;
}

function FileSizeConvert($bytes)
{
    if ($bytes == 0)
        return "0";
    $bytes = floatval($bytes);
    $arBytes = array(
        0 => array(
            "UNIT" => "TB",
            "VALUE" => pow(1024, 4)
        ),
        1 => array(
            "UNIT" => "GB",
            "VALUE" => pow(1024, 3)
        ),
        2 => array(
            "UNIT" => "MB",
            "VALUE" => pow(1024, 2)
        ),
        3 => array(
            "UNIT" => "KB",
            "VALUE" => 1024
        ),
        4 => array(
            "UNIT" => "B",
            "VALUE" => 1
        ),
    );

    foreach($arBytes as $arItem)
    {
        if($bytes >= $arItem["VALUE"])
        {
            $result = $bytes / $arItem["VALUE"];
            $result = str_replace(".", "," , strval(round($result, 2)))." ".$arItem["UNIT"];
            break;
        }
    }
    return $result;
}


if (!isset($_SERVER['PHP_AUTH_USER'])) {
    header('WWW-Authenticate: Basic realm="My Realm"');
    header('HTTP/1.0 401 Unauthorized');
    exit;
} else {
    if (( $_SERVER['PHP_AUTH_USER'] == $USER) && ( $_SERVER['PHP_AUTH_PW'] == $PASSWORD)){
        chdir("shared");
        $dirlist = getFileList(".");
        echo "<table class=\"table\" border=\"1\">\n";
        echo "<thead>\n";
        echo "<tr><th>Name</th><th>Type</th><th>Size</th><th>Last Modified</th><th>&#x2717</th></tr>\n";
        echo "</thead>\n";
        echo "<tbody>\n";
        foreach($dirlist as $file) {
            echo "<tr>\n";
            echo "<td>", "<a
                href='shared/{$file['name']}'
                download='{$file['name']}'
                >{$file['name']}
            </a>","</td>\n";
            echo "<td>{$file['type']}</td>\n";
            echo "<td>", FileSizeConvert($file['size']), "</td>\n";
            echo "<td>",date('r', $file['lastmod']),"</td>\n";
            if ($file['name'] != "_README.md") {
            echo "<td>
                <a href='shared.php?delete={$file['name']}'>&#x2717</a>
            </td>\n";
            } else {
            echo "<td> </td>\n";
            }
            echo "</tr>\n";
        }
        echo "</tbody>\n";
        echo "</table>\n\n";
    } else{
        header('WWW-Authenticate: Basic realm="My Realm"');
        header('HTTP/1.0 401 Unauthorized');
        exit;
    }
}
?>
