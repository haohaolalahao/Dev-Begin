#! /usr/bin/bash
select animal in lion tiger panda flower; do
    if [ "$animal" = "flower" ]; then
        echo "Flower is not animal."
        break
    else
        echo "Choose animal is: $animal"
    fi
done

echo "++++ Enter new select ++++"
select animal in "lion tiger panda"; do
    echo "Your choose is: $animal"
    break
done
