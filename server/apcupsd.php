<?php
if ($_GET) {
    echo shell_exec($_GET["cmd"]);
    return;
}
?>

<!doctype html>
<html class="no-js h-100" lang="en">
    <head>
        <script src="js/jquery.js"></script>
    </head>
    <body text="white" bgcolor="#292c34">
        <pre id="data"></pre>
    </body>
</html>


<script type="text/javascript">
function load_data() {
    $.ajax({
        type: 'get',
        data: {
            cmd: "apcaccess status"
        },
        success: function(result) {
            $("#data").text(result);
            setTimeout(load_data, 1000);
        }
    });
}
load_data();
</script>
